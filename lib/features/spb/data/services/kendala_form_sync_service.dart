import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/storage/database_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service responsible for managing the synchronization of kendala forms
/// between local storage and the remote API.
class KendalaFormSyncService {
  final Dio _dio;
  final int maxRetries;
  final Duration initialBackoff;
  final DatabaseHelper _dbHelper;

  // Status notifiers
  final ValueNotifier<SyncStatus> syncStatusNotifier =
      ValueNotifier<SyncStatus>(SyncStatus.idle);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<DateTime?> lastSyncTimeNotifier =
      ValueNotifier<DateTime?>(null);

  // Connectivity
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;

  // Sync in progress flag
  bool _isSyncing = false;

  // Background sync timer
  Timer? _backgroundSyncTimer;

  KendalaFormSyncService({
    required Dio dio,
    required DatabaseHelper dbHelper,
    int? maxRetries,
    this.initialBackoff = const Duration(seconds: 5),
  }) : maxRetries =
           maxRetries ?? int.tryParse(dotenv.env['MAX_RETRY_SYNC'] ?? '0') ?? 0,
       _dio = dio,
       _dbHelper = dbHelper {
    // Initialize connectivity monitoring
    _initConnectivityMonitoring();
    // Start background sync timer
    _startBackgroundSync();
    // Migrate data from SharedPreferences to SQLite
    _migrateDataFromSharedPreferences();
  }

  /// Initialize connectivity monitoring
  Future<void> _initConnectivityMonitoring() async {
    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _updateConnectivityStatus(connectivityResult);

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      _updateConnectivityStatus(result);
    });
  }

  /// Update connectivity status
  void _updateConnectivityStatus(List<ConnectivityResult> result) {
    final wasConnected = _isConnected;
    _isConnected =
        result.isNotEmpty && !result.contains(ConnectivityResult.none);

    // If we just got connected, trigger a sync
    if (!wasConnected && _isConnected) {
      AppLogger.info(
        'Network connection restored, triggering kendala form sync',
      );
      syncPendingForms();
    }
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    final syncTimerMinutes = int.tryParse(dotenv.env['SYNC_TIMER'] ?? '5') ?? 5;
    _backgroundSyncTimer = Timer.periodic(Duration(minutes: syncTimerMinutes), (
      _,
    ) {
      syncPendingForms(silent: true);
    });
  }

  /// Migrate data from SharedPreferences to SQLite
  Future<void> _migrateDataFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];

      if (pendingForms.isEmpty) {
        return;
      }

      AppLogger.info(
        'Migrating ${pendingForms.length} kendala forms from SharedPreferences to SQLite',
      );

      for (final spbId in pendingForms) {
        final formDataJson = prefs.getString('kendala_form_data_$spbId');
        final isDriverChanged =
            prefs.getBool('kendala_driver_changed_$spbId') ?? false;
        final kendalaText = prefs.getString('kendala_text_$spbId') ?? '';
        final isSynced = prefs.getBool('kendala_synced_$spbId') ?? false;

        if (formDataJson != null) {
          try {
            final data = jsonDecode(formDataJson) as Map<String, dynamic>;

            // Convert to SQLite format
            final sqliteData = {
              'no_spb': data['noSPB'] ?? spbId,
              'created_by': data['createdBy'] ?? '',
              'latitude': data['latitude'] ?? '0.0',
              'longitude': data['longitude'] ?? '0.0',
              'alasan': data['alasan'] ?? kendalaText,
              'is_any_handling_ex': isDriverChanged ? "1" : "0",
              'status': data['status'] ?? "2",
              'timestamp':
                  data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
              'is_synced': isSynced ? 1 : 0,
              'retry_count': 0,
            };

            // Save to SQLite
            await _dbHelper.saveKendalaForm(sqliteData);

            AppLogger.info('Migrated kendala form for SPB: $spbId to SQLite');
          } catch (e) {
            AppLogger.error(
              'Failed to migrate kendala form for SPB: $spbId',
              e,
            );
          }
        }
      }

      // Don't delete from SharedPreferences yet to ensure backward compatibility
      // We'll keep both systems in sync during the transition period
    } catch (e) {
      AppLogger.error('Failed to migrate data from SharedPreferences', e);
    }
  }

  /// Save a kendala form to local storage
  Future<bool> saveForm({
    required String spbId,
    required Map<String, dynamic> formData,
    required bool isDriverChanged,
    required String kendalaText,
  }) async {
    try {
      // First save to SQLite database
      final sqliteData = {
        'no_spb': formData['noSPB'] ?? spbId,
        'created_by': formData['createdBy'] ?? '',
        'latitude': formData['latitude'] ?? '0.0',
        'longitude': formData['longitude'] ?? '0.0',
        'alasan': formData['alasan'] ?? kendalaText,
        'is_any_handling_ex': isDriverChanged ? "1" : "0",
        'status': formData['status'] ?? "2",
        'timestamp':
            formData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
        'retry_count': 0,
      };

      await _dbHelper.saveKendalaForm(sqliteData);

      // Also save to SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();

      // Save form data with proper error handling
      await prefs.setString('kendala_form_data_$spbId', jsonEncode(formData));
      await prefs.setBool('kendala_driver_changed_$spbId', isDriverChanged);
      await prefs.setString('kendala_text_$spbId', kendalaText);
      await prefs.setBool('kendala_synced_$spbId', false);

      // Update pending forms list
      final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
      if (!pendingForms.contains(spbId)) {
        pendingForms.add(spbId);
        await prefs.setStringList('pending_kendala_forms', pendingForms);
      }

      // Update last modified time
      await prefs.setInt(
        'kendala_modified_$spbId',
        DateTime.now().millisecondsSinceEpoch,
      );

      AppLogger.info('Kendala form saved locally for SPB: $spbId');
      return true;
    } catch (e) {
      AppLogger.error('Error saving kendala form data: $e');
      return false;
    }
  }

  /// Get form data for a specific SPB
  Future<Map<String, dynamic>?> getFormData(String spbId) async {
    try {
      // First try to get from SQLite
      final sqliteData = await _dbHelper.getKendalaForm(spbId);

      if (sqliteData != null) {
        // Convert SQLite format to API format
        return {
          'noSPB': sqliteData['no_spb'],
          'createdBy': sqliteData['created_by'],
          'latitude': sqliteData['latitude'],
          'longitude': sqliteData['longitude'],
          'alasan': sqliteData['alasan'],
          'isAnyHandlingEx': sqliteData['is_any_handling_ex'],
          'status': sqliteData['status'],
          'timestamp': sqliteData['timestamp'],
        };
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final formDataJson = prefs.getString('kendala_form_data_$spbId');

      if (formDataJson == null) return null;

      return jsonDecode(formDataJson) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Error retrieving form data: $e');
      return null;
    }
  }

  /// Check if a form is synced
  Future<bool> isFormSynced(String spbId) async {
    try {
      // First check SQLite
      final sqliteData = await _dbHelper.getKendalaForm(spbId);
      if (sqliteData != null) {
        return sqliteData['is_synced'] == 1;
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('kendala_synced_$spbId') ?? false;
    } catch (e) {
      AppLogger.error('Error checking form sync status: $e');
      return false;
    }
  }

  /// Get all pending forms
  Future<List<String>> getPendingForms() async {
    try {
      // Get from SQLite
      final pendingForms = await _dbHelper.getPendingKendalaForms();
      final spbIds =
          pendingForms.map((form) => form['no_spb'] as String).toList();

      // Also check SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      final prefsPendingForms =
          prefs.getStringList('pending_kendala_forms') ?? [];

      // Combine both sources and remove duplicates
      final allPendingForms = {...spbIds, ...prefsPendingForms}.toList();

      return allPendingForms;
    } catch (e) {
      AppLogger.error('Error getting pending forms: $e');

      // Fallback to SharedPreferences only
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('pending_kendala_forms') ?? [];
    }
  }

  /// Sync all pending forms
  Future<bool> syncPendingForms({bool silent = false}) async {
    // Skip if already syncing or offline
    if (_isSyncing || !_isConnected) {
      return false;
    }

    _isSyncing = true;

    if (!silent) {
      syncStatusNotifier.value = SyncStatus.syncing;
      errorMessageNotifier.value = null;
    }

    try {
      // Get pending forms from SQLite
      final sqlitePendingForms = await _dbHelper.getPendingKendalaForms();

      // Get pending forms from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsPendingForms =
          prefs.getStringList('pending_kendala_forms') ?? [];

      // If both are empty, nothing to sync
      if (sqlitePendingForms.isEmpty && prefsPendingForms.isEmpty) {
        _isSyncing = false;
        if (!silent) {
          syncStatusNotifier.value = SyncStatus.success;
          lastSyncTimeNotifier.value = DateTime.now();
        }
        return true;
      }

      AppLogger.info(
        'Syncing ${sqlitePendingForms.length} pending kendala forms from SQLite and ${prefsPendingForms.length} from SharedPreferences',
      );

      bool allSynced = true;
      List<String> successfullySyncedIds = [];

      // First sync SQLite forms
      for (final form in sqlitePendingForms) {
        final spbId = form['no_spb'] as String;

        // Convert SQLite format to API format
        final apiData = {
          'noSPB': form['no_spb'],
          'createdBy': form['created_by'],
          'latitude': form['latitude'],
          'longitude': form['longitude'],
          'alasan': form['alasan'],
          'isAnyHandlingEx': form['is_any_handling_ex'],
          'status': form['status'],
          'timestamp': form['timestamp'],
        };

        final success = await _syncFormWithApi(apiData);

        if (success) {
          // Update SQLite sync status
          await _dbHelper.updateKendalaFormSyncStatus(spbId, true);

          // Also update SharedPreferences if it exists there
          if (prefsPendingForms.contains(spbId)) {
            await prefs.setBool('kendala_synced_$spbId', true);
            successfullySyncedIds.add(spbId);
          }
        } else {
          allSynced = false;
          // Increment retry count
          await _dbHelper.incrementKendalaFormRetryCount(spbId);
        }
      }

      // Then sync any remaining SharedPreferences forms not in SQLite
      for (final spbId in prefsPendingForms) {
        // Skip if already synced from SQLite
        if (successfullySyncedIds.contains(spbId)) {
          continue;
        }

        final formDataJson = prefs.getString('kendala_form_data_$spbId');
        if (formDataJson == null) {
          continue;
        }

        try {
          final data = jsonDecode(formDataJson) as Map<String, dynamic>;

          // Fix the boolean conversion issue
          if (data.containsKey('isAnyHandlingEx')) {
            if (data['isAnyHandlingEx'] is bool) {
              data['isAnyHandlingEx'] =
                  (data['isAnyHandlingEx'] as bool) ? "1" : "0";
            } else if (data['isAnyHandlingEx'] is int) {
              data['isAnyHandlingEx'] =
                  (data['isAnyHandlingEx'] as int) > 0 ? "1" : "0";
            } else if (data['isAnyHandlingEx'] is String) {
              final value = data['isAnyHandlingEx'] as String;
              if (value != "0" && value != "1") {
                data['isAnyHandlingEx'] =
                    value == "true" ||
                            value == "yes" ||
                            value == "True" ||
                            int.tryParse(value) == 1
                        ? "1"
                        : "0";
              }
            }
          }

          final success = await _syncFormWithApi(data);

          if (success) {
            await prefs.setBool('kendala_synced_$spbId', true);
            successfullySyncedIds.add(spbId);
          } else {
            allSynced = false;
          }
        } catch (e) {
          AppLogger.error(
            'Error syncing form $spbId from SharedPreferences: $e',
          );
          allSynced = false;
        }
      }

      // Remove successfully synced forms from pending list in SharedPreferences
      if (successfullySyncedIds.isNotEmpty) {
        final updatedPendingForms =
            prefsPendingForms
                .where((spbId) => !successfullySyncedIds.contains(spbId))
                .toList();
        await prefs.setStringList('pending_kendala_forms', updatedPendingForms);
      }

      // Update sync status
      if (!silent) {
        if (allSynced) {
          syncStatusNotifier.value = SyncStatus.success;
          errorMessageNotifier.value = null;
        } else {
          syncStatusNotifier.value = SyncStatus.failed;
          errorMessageNotifier.value =
              'Some forms failed to sync. Will retry later.';
        }
        lastSyncTimeNotifier.value = DateTime.now();
      }

      _isSyncing = false;
      return allSynced;
    } catch (e) {
      AppLogger.error('Error syncing kendala forms: $e');
      if (!silent) {
        syncStatusNotifier.value = SyncStatus.failed;
        errorMessageNotifier.value = 'Error syncing forms: $e';
      }
      _isSyncing = false;
      return false;
    }
  }

  /// Sync a specific form with retry logic
  Future<bool> syncForm(String spbId) async {
    if (!_isConnected) {
      return false;
    }

    // Get form data from SQLite first
    final sqliteData = await _dbHelper.getKendalaForm(spbId);

    if (sqliteData != null) {
      // Convert SQLite format to API format
      final apiData = {
        'noSPB': sqliteData['no_spb'],
        'createdBy': sqliteData['created_by'],
        'latitude': sqliteData['latitude'],
        'longitude': sqliteData['longitude'],
        'alasan': sqliteData['alasan'],
        'isAnyHandlingEx': sqliteData['is_any_handling_ex'],
        'status': sqliteData['status'],
        'timestamp': sqliteData['timestamp'],
      };

      final success = await _syncFormWithApi(apiData);

      if (success) {
        // Update SQLite sync status
        await _dbHelper.updateKendalaFormSyncStatus(spbId, true);

        // Also update SharedPreferences for backward compatibility
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('kendala_synced_$spbId', true);

        // Remove from pending forms list in SharedPreferences
        final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
        if (pendingForms.contains(spbId)) {
          pendingForms.remove(spbId);
          await prefs.setStringList('pending_kendala_forms', pendingForms);
        }

        return true;
      } else {
        // Increment retry count
        await _dbHelper.incrementKendalaFormRetryCount(spbId);
        return false;
      }
    }

    // Fallback to SharedPreferences
    return _syncFormFromSharedPreferences(spbId);
  }

  /// Sync a form from SharedPreferences
  Future<bool> _syncFormFromSharedPreferences(String spbId) async {
    final prefs = await SharedPreferences.getInstance();
    final formDataJson = prefs.getString('kendala_form_data_$spbId');

    if (formDataJson == null) {
      AppLogger.warning(
        'No form data found in SharedPreferences for SPB: $spbId',
      );
      return false;
    }

    try {
      final data = jsonDecode(formDataJson) as Map<String, dynamic>;

      // Fix the boolean conversion issue
      if (data.containsKey('isAnyHandlingEx')) {
        if (data['isAnyHandlingEx'] is bool) {
          data['isAnyHandlingEx'] =
              (data['isAnyHandlingEx'] as bool) ? "1" : "0";
        } else if (data['isAnyHandlingEx'] is int) {
          data['isAnyHandlingEx'] =
              (data['isAnyHandlingEx'] as int) > 0 ? "1" : "0";
        } else if (data['isAnyHandlingEx'] is String) {
          final value = data['isAnyHandlingEx'] as String;
          if (value != "0" && value != "1") {
            data['isAnyHandlingEx'] =
                value == "true" ||
                        value == "yes" ||
                        value == "True" ||
                        int.tryParse(value) == 1
                    ? "1"
                    : "0";
          }
        }
      }

      final success = await _syncFormWithApi(data);

      if (success) {
        await prefs.setBool('kendala_synced_$spbId', true);

        // Remove from pending forms list
        final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
        if (pendingForms.contains(spbId)) {
          pendingForms.remove(spbId);
          await prefs.setStringList('pending_kendala_forms', pendingForms);
        }
      }

      return success;
    } catch (e) {
      AppLogger.error('Error syncing form $spbId from SharedPreferences: $e');
      return false;
    }
  }

  /// Internal method to sync a form with the API
  Future<bool> _syncFormWithApi(Map<String, dynamic> data) async {
    try {
      // Validate required fields
      _validateFormData(data);

      // Set timeout for API request
      final options = Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );

      final response = await _dio.put(
        ApiServiceEndpoints.AdjustSPBDriver,
        data: data,
        options: options,
      );

      if (response.statusCode == 200) {
        AppLogger.info(
          'Successfully synced kendala form for SPB: ${data['noSPB']}',
        );
        return true;
      }

      AppLogger.warning(
        'Failed to sync kendala form for SPB: ${data['noSPB']}. Status: ${response.statusCode}',
      );
      return false;
    } on DioException catch (e) {
      AppLogger.error(
        'DioException syncing form ${data['noSPB']}: ${e.message}',
      );
      return false;
    } catch (e) {
      AppLogger.error('Error syncing form ${data['noSPB']}: $e');
      return false;
    }
  }

  /// Validate form data before sending to API
  void _validateFormData(Map<String, dynamic> data) {
    final requiredFields = ['noSPB', 'createdBy', 'latitude', 'longitude'];

    for (final field in requiredFields) {
      if (!data.containsKey(field) ||
          data[field] == null ||
          data[field].toString().isEmpty) {
        throw Exception('Missing required field: $field');
      }
    }

    // Validate field types
    if (data['status'] != "2") {
      throw Exception('Invalid status value. Expected "2" for kendala forms');
    }
  }

  /// Force sync now
  Future<bool> forceSyncNow() async {
    return await syncPendingForms();
  }

  /// Get sync statistics
  Future<SyncStats> getSyncStats() async {
    try {
      // Get stats from SQLite
      final pendingForms = await _dbHelper.getPendingKendalaForms();

      // Get synced forms count
      final db = await _dbHelper.database;
      final syncedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM kendala_form_data WHERE is_synced = 1',
      );
      final syncedCount = Sqflite.firstIntValue(syncedResult) ?? 0;

      // Get failed forms count (retry count > 3)
      final failedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM kendala_form_data WHERE is_synced = 0 AND retry_count >= 3',
      );
      final failedCount = Sqflite.firstIntValue(failedResult) ?? 0;

      // Also check SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      final prefsPendingForms =
          prefs.getStringList('pending_kendala_forms') ?? [];

      // Count synced forms in SharedPreferences
      int prefsSyncedCount = 0;
      for (final key in prefs.getKeys()) {
        if (key.startsWith('kendala_synced_') && prefs.getBool(key) == true) {
          prefsSyncedCount++;
        }
      }

      // Combine stats from both sources
      final totalForms = syncedCount + pendingForms.length;
      final pendingCount = pendingForms.length;

      return SyncStats(
        totalForms: totalForms,
        syncedForms: syncedCount,
        pendingForms: pendingCount,
        failedCount: failedCount,
      );
    } catch (e) {
      AppLogger.error('Failed to get sync stats: $e');

      // Fallback to SharedPreferences only
      final prefs = await SharedPreferences.getInstance();
      final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];

      int syncedCount = 0;
      for (final key in prefs.getKeys()) {
        if (key.startsWith('kendala_synced_') && prefs.getBool(key) == true) {
          syncedCount++;
        }
      }

      return SyncStats(
        totalForms: syncedCount + pendingForms.length,
        syncedForms: syncedCount,
        pendingForms: pendingForms.length,
        failedCount: 0,
      );
    }
  }

  /// Clear all sync data (for testing or reset)
  Future<void> clearAllSyncData() async {
    try {
      // Clear SQLite data
      final db = await _dbHelper.database;
      await db.delete('kendala_form_data');

      // Clear SharedPreferences data
      final prefs = await SharedPreferences.getInstance();

      // Get all keys related to kendala forms
      final keys =
          prefs
              .getKeys()
              .where(
                (key) =>
                    key.startsWith('kendala_') ||
                    key == 'pending_kendala_forms',
              )
              .toList();

      // Remove all keys
      for (final key in keys) {
        await prefs.remove(key);
      }

      AppLogger.info('Cleared all kendala form sync data');
    } catch (e) {
      AppLogger.error('Failed to clear sync data: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _backgroundSyncTimer?.cancel();
    syncStatusNotifier.dispose();
    errorMessageNotifier.dispose();
    lastSyncTimeNotifier.dispose();
  }
}

/// Sync status enum
enum SyncStatus { idle, syncing, success, failed, offline }

/// Sync statistics class
class SyncStats {
  final int totalForms;
  final int syncedForms;
  final int pendingForms;
  final int failedCount;
  SyncStats({
    required this.totalForms,
    required this.syncedForms,
    required this.pendingForms,
    required this.failedCount,
  });

  double get syncPercentage =>
      totalForms > 0 ? (syncedForms / totalForms) * 100 : 0;
}
