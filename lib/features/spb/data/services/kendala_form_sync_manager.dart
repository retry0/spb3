import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/storage/database_helper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/di/injection.dart';

/// A comprehensive service for managing the synchronization of kendala forms
/// between SharedPreferences, SQLite database, and the remote API.
class KendalaFormSyncManager {
  final Dio _dio;
  final DatabaseHelper _dbHelper;
  final int maxRetries;
  final Duration initialBackoff;

  // Status notifiers
  final ValueNotifier<SyncStatus> syncStatusNotifier =
      ValueNotifier<SyncStatus>(SyncStatus.idle);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<DateTime?> lastSyncTimeNotifier = ValueNotifier<DateTime?>(null);

  // Connectivity
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;

  // Sync in progress flag
  bool _isSyncing = false;

  // Background sync timer
  Timer? _backgroundSyncTimer;

  KendalaFormSyncManager({
    required Dio dio,
    required DatabaseHelper dbHelper,
    this.maxRetries = 3,
    this.initialBackoff = const Duration(seconds: 5),
  }) : _dio = dio,
       _dbHelper = dbHelper {
    // Initialize connectivity monitoring
    _initConnectivityMonitoring();
    
    // Start background sync timer
    _startBackgroundSync();
  }

  /// Initialize connectivity monitoring
  Future<void> _initConnectivityMonitoring() async {
    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _updateConnectivityStatus(connectivityResult);

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _updateConnectivityStatus(result);
    });
  }

  /// Update connectivity status
  void _updateConnectivityStatus(List<ConnectivityResult> result) {
    final wasConnected = _isConnected;
    _isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);

    // If we just got connected, trigger a sync
    if (!wasConnected && _isConnected) {
      AppLogger.info('Network connection restored, triggering kendala form sync');
      syncPendingForms();
    }
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      syncPendingForms(silent: true);
    });
  }

  /// Migrate form data from SharedPreferences to SQLite database
  Future<bool> migrateFormsToDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
      
      if (pendingForms.isEmpty) return true;
      
      AppLogger.info('Migrating ${pendingForms.length} forms from SharedPreferences to SQLite');
      
      int successCount = 0;
      
      for (final spbId in pendingForms) {
        try {
          // Get form data from SharedPreferences
          final formDataJson = prefs.getString('kendala_form_data_$spbId');
          final isDriverChanged = prefs.getBool('kendala_driver_changed_$spbId') ?? false;
          final kendalaText = prefs.getString('kendala_text_$spbId') ?? '';
          final isSynced = prefs.getBool('kendala_synced_$spbId') ?? false;
          final modifiedTime = prefs.getInt('kendala_modified_$spbId') ?? 
              DateTime.now().millisecondsSinceEpoch;
          
          if (formDataJson == null) continue;
          
          // Parse form data
          final data = jsonDecode(formDataJson) as Map<String, dynamic>;
          
          // Create database record
          await _dbHelper.transaction((txn) async {
            // Check if record already exists
            final existingRecords = await txn.query(
              'espb_form_data',
              where: 'no_spb = ?',
              whereArgs: [spbId],
              limit: 1,
            );
            
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            
            if (existingRecords.isEmpty) {
              // Insert new record
              await txn.insert('espb_form_data', {
                'no_spb': spbId,
                'status': data['status'] ?? '2', // Default to kendala status
                'created_by': data['createdBy'] ?? '',
                'latitude': data['latitude'] ?? '0.0',
                'longitude': data['longitude'] ?? '0.0',
                'alasan': kendalaText,
                'is_any_handling_ex': isDriverChanged ? 1 : 0,
                'timestamp': data['timestamp'] ?? modifiedTime ~/ 1000,
                'is_synced': isSynced ? 1 : 0,
                'retry_count': 0,
                'last_error': null,
                'created_at': now,
                'updated_at': now,
              });
            } else {
              // Update existing record
              await txn.update(
                'espb_form_data',
                {
                  'status': data['status'] ?? '2',
                  'created_by': data['createdBy'] ?? '',
                  'latitude': data['latitude'] ?? '0.0',
                  'longitude': data['longitude'] ?? '0.0',
                  'alasan': kendalaText,
                  'is_any_handling_ex': isDriverChanged ? 1 : 0,
                  'timestamp': data['timestamp'] ?? modifiedTime ~/ 1000,
                  'is_synced': isSynced ? 1 : 0,
                  'updated_at': now,
                },
                where: 'no_spb = ?',
                whereArgs: [spbId],
              );
            }
          });
          
          successCount++;
        } catch (e) {
          AppLogger.error('Failed to migrate form $spbId: $e');
        }
      }
      
      AppLogger.info('Successfully migrated $successCount/${pendingForms.length} forms to database');
      return successCount == pendingForms.length;
    } catch (e) {
      AppLogger.error('Failed to migrate forms to database: $e');
      return false;
    }
  }

  /// Save a kendala form to both SharedPreferences and SQLite database
  Future<bool> saveForm({
    required String spbId,
    required Map<String, dynamic> formData,
    required bool isDriverChanged,
    required String kendalaText,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Save to SharedPreferences for backward compatibility
      await prefs.setString('kendala_form_data_$spbId', jsonEncode(formData));
      await prefs.setBool('kendala_driver_changed_$spbId', isDriverChanged);
      await prefs.setString('kendala_text_$spbId', kendalaText);
      await prefs.setBool('kendala_synced_$spbId', false);
      await prefs.setInt('kendala_modified_$spbId', now);
      
      // Update pending forms list in SharedPreferences
      final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
      if (!pendingForms.contains(spbId)) {
        pendingForms.add(spbId);
        await prefs.setStringList('pending_kendala_forms', pendingForms);
      }
      
      // Save to SQLite database
      await _dbHelper.transaction((txn) async {
        // Check if record already exists
        final existingRecords = await txn.query(
          'espb_form_data',
          where: 'no_spb = ?',
          whereArgs: [spbId],
          limit: 1,
        );
        
        final nowSeconds = now ~/ 1000;
        
        if (existingRecords.isEmpty) {
          // Insert new record
          await txn.insert('espb_form_data', {
            'no_spb': spbId,
            'status': formData['status'] ?? '2', // Default to kendala status
            'created_by': formData['createdBy'] ?? '',
            'latitude': formData['latitude'] ?? '0.0',
            'longitude': formData['longitude'] ?? '0.0',
            'alasan': kendalaText,
            'is_any_handling_ex': isDriverChanged ? 1 : 0,
            'timestamp': formData['timestamp'] ?? nowSeconds,
            'is_synced': 0,
            'retry_count': 0,
            'last_error': null,
            'created_at': nowSeconds,
            'updated_at': nowSeconds,
          });
        } else {
          // Update existing record
          await txn.update(
            'espb_form_data',
            {
              'status': formData['status'] ?? '2',
              'created_by': formData['createdBy'] ?? '',
              'latitude': formData['latitude'] ?? '0.0',
              'longitude': formData['longitude'] ?? '0.0',
              'alasan': kendalaText,
              'is_any_handling_ex': isDriverChanged ? 1 : 0,
              'timestamp': formData['timestamp'] ?? nowSeconds,
              'is_synced': 0,
              'updated_at': nowSeconds,
            },
            where: 'no_spb = ?',
            whereArgs: [spbId],
          );
        }
      });
      
      AppLogger.info('Kendala form saved locally for SPB: $spbId');
      return true;
    } catch (e) {
      AppLogger.error('Error saving kendala form data: $e');
      return false;
    }
  }

  /// Get form data for a specific SPB from both sources
  Future<Map<String, dynamic>?> getFormData(String spbId) async {
    try {
      // First try to get from SQLite database
      final results = await _dbHelper.query(
        'espb_form_data',
        where: 'no_spb = ?',
        whereArgs: [spbId],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        final dbData = results.first;
        return {
          'noSPB': dbData['no_spb'] as String,
          'status': dbData['status'] as String,
          'createdBy': dbData['created_by'] as String,
          'latitude': dbData['latitude'] as String,
          'longitude': dbData['longitude'] as String,
          'alasan': dbData['alasan'] as String?,
          'isAnyHandlingEx': (dbData['is_any_handling_ex'] as int) == 1 ? "1" : "0",
          'timestamp': dbData['timestamp'] as int,
          'isSynced': (dbData['is_synced'] as int) == 1,
          'retryCount': dbData['retry_count'] as int,
          'lastError': dbData['last_error'] as String?,
          'createdAt': dbData['created_at'] as int,
          'updatedAt': dbData['updated_at'] as int,
        };
      }
      
      // Fallback to SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      final formDataJson = prefs.getString('kendala_form_data_$spbId');
      
      if (formDataJson == null) return null;
      
      final data = jsonDecode(formDataJson) as Map<String, dynamic>;
      final isDriverChanged = prefs.getBool('kendala_driver_changed_$spbId') ?? false;
      final kendalaText = prefs.getString('kendala_text_$spbId') ?? '';
      final isSynced = prefs.getBool('kendala_synced_$spbId') ?? false;
      
      return {
        ...data,
        'alasan': kendalaText,
        'isAnyHandlingEx': isDriverChanged ? "1" : "0",
        'isSynced': isSynced,
      };
    } catch (e) {
      AppLogger.error('Error retrieving form data: $e');
      return null;
    }
  }

  /// Check if a form is synced
  Future<bool> isFormSynced(String spbId) async {
    try {
      // First check SQLite database
      final results = await _dbHelper.query(
        'espb_form_data',
        columns: ['is_synced'],
        where: 'no_spb = ?',
        whereArgs: [spbId],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        return (results.first['is_synced'] as int) == 1;
      }
      
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('kendala_synced_$spbId') ?? false;
    } catch (e) {
      AppLogger.error('Error checking sync status: $e');
      return false;
    }
  }

  /// Get all pending forms from both sources
  Future<List<String>> getPendingForms() async {
    try {
      final Set<String> pendingForms = {};
      
      // Get from SQLite database
      final results = await _dbHelper.query(
        'espb_form_data',
        columns: ['no_spb'],
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      
      for (final row in results) {
        pendingForms.add(row['no_spb'] as String);
      }
      
      // Get from SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      final prefsForms = prefs.getStringList('pending_kendala_forms') ?? [];
      
      pendingForms.addAll(prefsForms);
      
      return pendingForms.toList();
    } catch (e) {
      AppLogger.error('Error getting pending forms: $e');
      return [];
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
      // Get pending forms from both sources
      final pendingForms = await getPendingForms();
      
      if (pendingForms.isEmpty) {
        _isSyncing = false;
        if (!silent) {
          syncStatusNotifier.value = SyncStatus.success;
          lastSyncTimeNotifier.value = DateTime.now();
        }
        return true;
      }
      
      AppLogger.info('Syncing ${pendingForms.length} pending kendala forms');
      
      bool allSynced = true;
      List<String> successfullySync = [];
      
      for (final spbId in pendingForms) {
        final success = await _syncForm(spbId);
        if (success) {
          successfullySync.add(spbId);
        } else {
          allSynced = false;
        }
      }
      
      // Update pending forms list in SharedPreferences
      if (successfullySync.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final prefsPendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
        final updatedPendingForms = prefsPendingForms.where((spbId) => !successfullySync.contains(spbId)).toList();
        await prefs.setStringList('pending_kendala_forms', updatedPendingForms);
      }
      
      // Update sync status
      if (!silent) {
        if (allSynced) {
          syncStatusNotifier.value = SyncStatus.success;
          errorMessageNotifier.value = null;
        } else {
          syncStatusNotifier.value = SyncStatus.failed;
          errorMessageNotifier.value = 'Some forms failed to sync. Will retry later.';
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
    
    return _syncForm(spbId);
  }

  /// Internal method to sync a form with retry logic
  Future<bool> _syncForm(String spbId, {int retryCount = 0}) async {
    try {
      // Get form data from database
      final results = await _dbHelper.query(
        'espb_form_data',
        where: 'no_spb = ?',
        whereArgs: [spbId],
        limit: 1,
      );
      
      Map<String, dynamic>? formData;
      
      if (results.isNotEmpty) {
        final dbData = results.first;
        formData = {
          'noSPB': dbData['no_spb'] as String,
          'status': dbData['status'] as String,
          'createdBy': dbData['created_by'] as String,
          'latitude': dbData['latitude'] as String,
          'longitude': dbData['longitude'] as String,
          'alasan': dbData['alasan'] as String?,
          'isAnyHandlingEx': (dbData['is_any_handling_ex'] as int) == 1 ? "1" : "0",
          'timestamp': dbData['timestamp'] as int,
        };
      } else {
        // Fallback to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final formDataJson = prefs.getString('kendala_form_data_$spbId');
        
        if (formDataJson == null) {
          AppLogger.warning('No form data found for SPB: $spbId');
          return false;
        }
        
        formData = jsonDecode(formDataJson) as Map<String, dynamic>;
        final isDriverChanged = prefs.getBool('kendala_driver_changed_$spbId') ?? false;
        final kendalaText = prefs.getString('kendala_text_$spbId') ?? '';
        
        // Add missing fields
        formData['alasan'] = kendalaText;
        formData['isAnyHandlingEx'] = isDriverChanged ? "1" : "0";
      }
      
      // Ensure isAnyHandlingEx is properly formatted as string "1" or "0"
      if (formData.containsKey('isAnyHandlingEx')) {
        if (formData['isAnyHandlingEx'] is bool) {
          formData['isAnyHandlingEx'] = (formData['isAnyHandlingEx'] as bool) ? "1" : "0";
        } else if (formData['isAnyHandlingEx'] is int) {
          formData['isAnyHandlingEx'] = (formData['isAnyHandlingEx'] as int) > 0 ? "1" : "0";
        } else if (formData['isAnyHandlingEx'] is String) {
          // If it's already a string, make sure it's "1" or "0"
          final value = formData['isAnyHandlingEx'] as String;
          if (value != "0" && value != "1") {
            formData['isAnyHandlingEx'] = value == "true" || value == "yes" || int.tryParse(value) == 1 ? "1" : "0";
          }
        }
      }
      
      // Validate required fields
      _validateFormData(formData);
      
      // Set timeout for API request
      final options = Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );
      
      // Make API request
      final response = await _dio.put(
        ApiServiceEndpoints.AdjustSPBDriver,
        data: formData,
        options: options,
      );
      
      if (response.statusCode == 200) {
        // Update sync status in database
        await _dbHelper.transaction((txn) async {
          // Check if record exists in database
          final existingRecords = await txn.query(
            'espb_form_data',
            columns: ['id'],
            where: 'no_spb = ?',
            whereArgs: [spbId],
            limit: 1,
          );
          
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          
          if (existingRecords.isNotEmpty) {
            // Update existing record
            await txn.update(
              'espb_form_data',
              {
                'is_synced': 1,
                'retry_count': 0,
                'last_error': null,
                'updated_at': now,
              },
              where: 'no_spb = ?',
              whereArgs: [spbId],
            );
          } else {
            // Insert new record if not in database yet
            await txn.insert('espb_form_data', {
              'no_spb': spbId,
              'status': formData['status'] ?? '2',
              'created_by': formData['createdBy'] ?? '',
              'latitude': formData['latitude'] ?? '0.0',
              'longitude': formData['longitude'] ?? '0.0',
              'alasan': formData['alasan'] ?? '',
              'is_any_handling_ex': formData['isAnyHandlingEx'] == "1" ? 1 : 0,
              'timestamp': formData['timestamp'] ?? now,
              'is_synced': 1,
              'retry_count': 0,
              'last_error': null,
              'created_at': now,
              'updated_at': now,
            });
          }
        });
        
        // Update sync status in SharedPreferences for backward compatibility
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('kendala_synced_$spbId', true);
        
        AppLogger.info('Successfully synced kendala form for SPB: $spbId');
        return true;
      }
      
      AppLogger.warning('Failed to sync kendala form for SPB: $spbId. Status: ${response.statusCode}');
      
      // Update retry count in database
      await _updateRetryCount(spbId, retryCount, 'API returned status ${response.statusCode}');
      
      // Retry logic
      if (retryCount < maxRetries) {
        final backoff = initialBackoff * pow(2, retryCount);
        AppLogger.info('Retrying sync for SPB: $spbId in ${backoff.inSeconds} seconds (attempt ${retryCount + 1}/$maxRetries)');
        await Future.delayed(backoff);
        return _syncForm(spbId, retryCount: retryCount + 1);
      }
      
      return false;
    } on DioException catch (e) {
      AppLogger.error('DioException syncing form $spbId (attempt ${retryCount + 1}): ${e.message}');
      
      // Update retry count in database
      await _updateRetryCount(spbId, retryCount, 'Network error: ${e.message}');
      
      // Retry for certain error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        if (retryCount < maxRetries) {
          final backoff = initialBackoff * pow(2, retryCount);
          AppLogger.info('Retrying sync for SPB: $spbId in ${backoff.inSeconds} seconds (attempt ${retryCount + 1}/$maxRetries)');
          await Future.delayed(backoff);
          return _syncForm(spbId, retryCount: retryCount + 1);
        }
      }
      
      return false;
    } catch (e) {
      AppLogger.error('Error syncing form $spbId (attempt ${retryCount + 1}): $e');
      
      // Update retry count in database
      await _updateRetryCount(spbId, retryCount, 'Error: $e');
      
      // Retry for general errors
      if (retryCount < maxRetries) {
        final backoff = initialBackoff * pow(2, retryCount);
        AppLogger.info('Retrying sync for SPB: $spbId in ${backoff.inSeconds} seconds (attempt ${retryCount + 1}/$maxRetries)');
        await Future.delayed(backoff);
        return _syncForm(spbId, retryCount: retryCount + 1);
      }
      
      return false;
    }
  }

  /// Update retry count in database
  Future<void> _updateRetryCount(String spbId, int currentRetryCount, String errorMessage) async {
    try {
      await _dbHelper.transaction((txn) async {
        // Check if record exists in database
        final existingRecords = await txn.query(
          'espb_form_data',
          columns: ['id'],
          where: 'no_spb = ?',
          whereArgs: [spbId],
          limit: 1,
        );
        
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final newRetryCount = currentRetryCount + 1;
        
        if (existingRecords.isNotEmpty) {
          // Update existing record
          await txn.update(
            'espb_form_data',
            {
              'retry_count': newRetryCount,
              'last_error': errorMessage,
              'updated_at': now,
            },
            where: 'no_spb = ?',
            whereArgs: [spbId],
          );
        }
      });
    } catch (e) {
      AppLogger.error('Failed to update retry count for $spbId: $e');
    }
  }

  /// Validate form data before sending to API
  void _validateFormData(Map<String, dynamic> data) {
    final requiredFields = ['noSPB', 'status', 'createdBy', 'latitude', 'longitude'];
    
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null || data[field].toString().isEmpty) {
        throw Exception('Missing required field: $field');
      }
    }
  }

  /// Force sync now
  Future<bool> forceSyncNow() async {
    return await syncPendingForms();
  }

  /// Get sync statistics
  Future<SyncStats> getSyncStats() async {
    try {
      int syncedCount = 0;
      int pendingCount = 0;
      int failedCount = 0;
      
      // Get stats from database
      final results = await _dbHelper.query(
        'espb_form_data',
        columns: ['is_synced', 'retry_count'],
      );
      
      for (final row in results) {
        final isSynced = (row['is_synced'] as int) == 1;
        final retryCount = row['retry_count'] as int;
        
        if (isSynced) {
          syncedCount++;
        } else {
          pendingCount++;
          if (retryCount >= maxRetries) {
            failedCount++;
          }
        }
      }
      
      // Get stats from SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      final prefsForms = prefs.getStringList('pending_kendala_forms') ?? [];
      
      for (final spbId in prefsForms) {
        final isSynced = prefs.getBool('kendala_synced_$spbId') ?? false;
        if (isSynced) {
          // This shouldn't happen, but just in case
          syncedCount++;
        } else {
          pendingCount++;
        }
      }
      
      return SyncStats(
        totalForms: syncedCount + pendingCount,
        syncedForms: syncedCount,
        pendingForms: pendingCount,
        failedCount: failedCount,
      );
    } catch (e) {
      AppLogger.error('Failed to get sync stats: $e');
      return SyncStats(
        totalForms: 0,
        syncedForms: 0,
        pendingForms: 0,
        failedCount: 0,
      );
    }
  }

  /// Clear all sync data (for testing or reset)
  Future<void> clearAllSyncData() async {
    try {
      // Clear database records
      await _dbHelper.delete('espb_form_data');
      
      // Clear SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys related to kendala forms
      final keys = prefs.getKeys().where(
        (key) => key.startsWith('kendala_') || key == 'pending_kendala_forms',
      ).toList();
      
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
  
  double get syncPercentage => totalForms > 0 ? (syncedForms / totalForms) * 100 : 0;
}