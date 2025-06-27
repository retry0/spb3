import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/utils/logger.dart';

/// Service responsible for managing the synchronization of kendala forms
/// between local storage and the remote API.
class CekFormSyncService {
  final Dio _dio;
  final int maxRetries;
  final Duration initialBackoff;

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

  CekFormSyncService({
    required Dio dio,
    this.maxRetries = 3,
    this.initialBackoff = const Duration(seconds: 5),
  }) : _dio = dio {
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
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      syncPendingForms(silent: true);
    });
  }

  /// Save a kendala form to local storage
  Future<bool> saveForm({
    required String spbId,
    required Map<String, dynamic> formData,
    required bool isDriverChanged,
    required String kendalaText,
  }) async {
    try {
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('kendala_synced_$spbId') ?? false;
  }

  /// Get all pending forms
  Future<List<String>> getPendingForms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('pending_kendala_forms') ?? [];
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
      final prefs = await SharedPreferences.getInstance();
      final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];

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

      // Remove successfully synced forms from pending list
      if (successfullySync.isNotEmpty) {
        final updatedPendingForms =
            pendingForms
                .where((spbId) => !successfullySync.contains(spbId))
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

    return _syncForm(spbId);
  }

  /// Internal method to sync a form with retry logic
  Future<bool> _syncForm(String spbId, {int retryCount = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final formDataJson = prefs.getString('kendala_form_data_$spbId');
    print('form $formDataJson');
    if (formDataJson == null) {
      AppLogger.warning('No form data found for SPB: $spbId');
      return false;
    }

    try {
      final data = jsonDecode(formDataJson) as Map<String, dynamic>;
      print('cek DATA SPB $data');
      // Validate required fields
      _validateFormData(data);

      // Set timeout for API request
      final options = Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );

      final response = await _dio.put(
        ApiServiceEndpoints.AcceptSPBDriver,
        data: data,
        options: options,
      );

      if (response.statusCode == 200) {
        await prefs.setBool('cek_synced_$spbId', true);
        AppLogger.info('Successfully synced kendala form for SPB: $spbId');
        return true;
      }

      AppLogger.warning(
        'Failed to sync kendala form for SPB: $spbId. Status: ${response.statusCode}',
      );

      // Retry logic
      if (retryCount < maxRetries) {
        final backoff = initialBackoff * pow(2, retryCount);
        AppLogger.info(
          'Retrying sync for SPB: $spbId in ${backoff.inSeconds} seconds (attempt ${retryCount + 1}/$maxRetries)',
        );
        await Future.delayed(backoff);
        return _syncForm(spbId, retryCount: retryCount + 1);
      }

      return false;
    } on DioException catch (e) {
      AppLogger.error(
        'DioException syncing form $spbId (attempt ${retryCount + 1}): ${e.message}',
      );

      // Retry for certain error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        if (retryCount < maxRetries) {
          final backoff = initialBackoff * pow(2, retryCount);
          AppLogger.info(
            'Retrying sync for SPB: $spbId in ${backoff.inSeconds} seconds (attempt ${retryCount + 1}/$maxRetries)',
          );
          await Future.delayed(backoff);
          return _syncForm(spbId, retryCount: retryCount + 1);
        }
      }

      return false;
    } catch (e) {
      AppLogger.error(
        'Error syncing form $spbId (attempt ${retryCount + 1}): $e',
      );

      // Retry for general errors
      if (retryCount < maxRetries) {
        final backoff = initialBackoff * pow(2, retryCount);
        AppLogger.info(
          'Retrying sync for SPB: $spbId in ${backoff.inSeconds} seconds (attempt ${retryCount + 1}/$maxRetries)',
        );
        await Future.delayed(backoff);
        return _syncForm(spbId, retryCount: retryCount + 1);
      }

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
  }

  /// Force sync now
  Future<bool> forceSyncNow() async {
    return await syncPendingForms();
  }

  /// Get sync statistics
  Future<SyncStats> getSyncStats() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];

    int syncedCount = 0;
    int pendingCount = pendingForms.length;
    int failedCount = 0;

    // Count synced forms
    for (final key in prefs.getKeys()) {
      if (key.startsWith('kendala_synced_') && prefs.getBool(key) == true) {
        syncedCount++;
      }
    }

    return SyncStats(
      totalForms: syncedCount + pendingCount,
      syncedForms: syncedCount,
      pendingForms: pendingCount,
      failedCount: failedCount,
    );
  }

  /// Clear all sync data (for testing or reset)
  Future<void> clearAllSyncData() async {
    final prefs = await SharedPreferences.getInstance();

    // Get all keys related to kendala forms
    final keys =
        prefs
            .getKeys()
            .where(
              (key) =>
                  key.startsWith('kendala_') || key == 'pending_kendala_forms',
            )
            .toList();

    // Remove all keys
    for (final key in keys) {
      await prefs.remove(key);
    }

    AppLogger.info('Cleared all kendala form sync data');
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
