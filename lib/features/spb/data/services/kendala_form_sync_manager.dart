import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/storage/database_helper.dart';

/// Service responsible for managing the synchronization of kendala forms
/// between SQLite database and the remote API.
class KendalaFormSyncManager {
  final Dio _dio;
  final DatabaseHelper _dbHelper;
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
    // Start background sync timer
    _startBackgroundSync();
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      syncPendingForms(silent: true);
    });
  }

  /// Sync all pending forms
  Future<bool> syncPendingForms({bool silent = false}) async {
    // Skip if already syncing
    if (_isSyncing) {
      return false;
    }

    _isSyncing = true;

    if (!silent) {
      syncStatusNotifier.value = SyncStatus.syncing;
      errorMessageNotifier.value = null;
    }

    try {
      final db = await _dbHelper.database;
      
      // Get all unsynced forms
      final results = await db.query(
        'kendala_forms',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      if (results.isEmpty) {
        _isSyncing = false;
        if (!silent) {
          syncStatusNotifier.value = SyncStatus.success;
          lastSyncTimeNotifier.value = DateTime.now();
        }
        return true;
      }

      AppLogger.info('Syncing ${results.length} pending Kendala forms');

      bool allSynced = true;
      int successCount = 0;

      for (final form in results) {
        final spbId = form['no_spb'] as String;
        final success = await _syncForm(form);
        
        if (success) {
          successCount++;
        } else {
          allSynced = false;
        }
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

      AppLogger.info('Sync completed: $successCount/${results.length} forms synced successfully');
      _isSyncing = false;
      return allSynced;
    } catch (e) {
      AppLogger.error('Error syncing Kendala forms: $e');
      if (!silent) {
        syncStatusNotifier.value = SyncStatus.failed;
        errorMessageNotifier.value = 'Error syncing forms: $e';
      }
      _isSyncing = false;
      return false;
    }
  }

  /// Sync a specific form
  Future<bool> syncForm(String spbId) async {
    try {
      final db = await _dbHelper.database;
      
      final results = await db.query(
        'kendala_forms',
        where: 'no_spb = ?',
        whereArgs: [spbId],
        limit: 1,
      );
      
      if (results.isEmpty) {
        AppLogger.warning('No form data found for SPB: $spbId');
        return false;
      }
      
      return _syncForm(results.first);
    } catch (e) {
      AppLogger.error('Error syncing form: $e');
      return false;
    }
  }

  /// Internal method to sync a form with retry logic
  Future<bool> _syncForm(Map<String, dynamic> formData, {int retryCount = 0}) async {
    final spbId = formData['no_spb'] as String;
    
    try {
      // Convert database format to API format
      final apiData = {
        'noSPB': formData['no_spb'],
        'createdBy': formData['created_by'],
        'latitude': formData['latitude'],
        'longitude': formData['longitude'],
        'alasan': formData['alasan'],
        'isAnyHandlingEx': formData['is_any_handling_ex'],
        'status': "2", // Set status to indicate kendala/issue
      };
      
      // Validate required fields
      _validateFormData(apiData);

      // Set timeout for API request
      final options = Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );

      final response = await _dio.put(
        ApiServiceEndpoints.AdjustSPBDriver,
        data: apiData,
        options: options,
      );

      if (response.statusCode == 200) {
        // Update database record
        await _dbHelper.update(
          'kendala_forms',
          {
            'is_synced': 1,
            'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          },
          where: 'no_spb = ?',
          whereArgs: [spbId],
        );
        
        AppLogger.info('Successfully synced Kendala form for SPB: $spbId');
        return true;
      }

      AppLogger.warning(
        'Failed to sync Kendala form for SPB: $spbId. Status: ${response.statusCode}',
      );

      // Retry logic
      if (retryCount < maxRetries) {
        final backoff = initialBackoff * pow(2, retryCount);
        AppLogger.info(
          'Retrying sync for SPB: $spbId in ${backoff.inSeconds} seconds (attempt ${retryCount + 1}/$maxRetries)',
        );
        await Future.delayed(backoff);
        return _syncForm(formData, retryCount: retryCount + 1);
      }
      
      // Update retry count in database
      await _dbHelper.update(
        'kendala_forms',
        {
          'retry_count': (formData['retry_count'] as int) + 1,
          'last_error': 'API returned status code: ${response.statusCode}',
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'no_spb = ?',
        whereArgs: [spbId],
      );

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
          return _syncForm(formData, retryCount: retryCount + 1);
        }
      }
      
      // Update retry count and error in database
      await _dbHelper.update(
        'kendala_forms',
        {
          'retry_count': (formData['retry_count'] as int) + 1,
          'last_error': 'Network error: ${e.message}',
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'no_spb = ?',
        whereArgs: [spbId],
      );

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
        return _syncForm(formData, retryCount: retryCount + 1);
      }
      
      // Update retry count and error in database
      await _dbHelper.update(
        'kendala_forms',
        {
          'retry_count': (formData['retry_count'] as int) + 1,
          'last_error': 'Error: $e',
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'no_spb = ?',
        whereArgs: [spbId],
      );

      return false;
    }
  }

  /// Validate form data before sending to API
  void _validateFormData(Map<String, dynamic> data) {
    final requiredFields = [
      'noSPB',
      'createdBy',
      'latitude',
      'longitude',
    ];

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
    try {
      final db = await _dbHelper.database;
      
      // Count total forms
      final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM kendala_forms');
      final totalForms = Sqflite.firstIntValue(totalResult) ?? 0;
      
      // Count synced forms
      final syncedResult = await db.rawQuery('SELECT COUNT(*) as count FROM kendala_forms WHERE is_synced = 1');
      final syncedForms = Sqflite.firstIntValue(syncedResult) ?? 0;
      
      // Count failed forms
      final failedResult = await db.rawQuery('SELECT COUNT(*) as count FROM kendala_forms WHERE retry_count >= ?', [maxRetries]);
      final failedCount = Sqflite.firstIntValue(failedResult) ?? 0;
      
      return SyncStats(
        totalForms: totalForms,
        syncedForms: syncedForms,
        pendingForms: totalForms - syncedForms,
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

  /// Check if a form is synced
  Future<bool> isFormSynced(String spbId) async {
    try {
      final db = await _dbHelper.database;
      
      final results = await db.query(
        'kendala_forms',
        columns: ['is_synced'],
        where: 'no_spb = ?',
        whereArgs: [spbId],
        limit: 1,
      );
      
      if (results.isEmpty) return false;
      
      return results.first['is_synced'] == 1;
    } catch (e) {
      AppLogger.error('Error checking sync status: $e');
      return false;
    }
  }

  /// Get all pending forms
  Future<List<String>> getPendingForms() async {
    try {
      final db = await _dbHelper.database;
      
      final results = await db.query(
        'kendala_forms',
        columns: ['no_spb'],
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      
      return results.map((row) => row['no_spb'] as String).toList();
    } catch (e) {
      AppLogger.error('Error getting pending forms: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
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