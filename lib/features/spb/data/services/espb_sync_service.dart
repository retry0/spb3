import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/usecases/sync_all_pending_espb_forms_usecase.dart';
import '../../domain/usecases/sync_espb_form_usecase.dart';
import '../../domain/usecases/get_espb_form_usecase.dart';

/// Service responsible for managing the synchronization of ESPB forms
/// between local storage and the remote API.
class EspbSyncService {
  final SyncAllPendingEspbFormsUseCase _syncAllPendingEspbFormsUseCase;
  final SyncEspbFormUseCase _syncEspbFormUseCase;
  final GetEspbFormUseCase _getEspbFormUseCase;
  final int maxRetries;
  final Duration initialBackoff;

  // Status notifiers
  final ValueNotifier<SyncStatus> syncStatusNotifier = ValueNotifier<SyncStatus>(SyncStatus.idle);
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

  EspbSyncService({
    required SyncAllPendingEspbFormsUseCase syncAllPendingEspbFormsUseCase,
    required SyncEspbFormUseCase syncEspbFormUseCase,
    required GetEspbFormUseCase getEspbFormUseCase,
    this.maxRetries = 3,
    this.initialBackoff = const Duration(seconds: 5),
  }) : _syncAllPendingEspbFormsUseCase = syncAllPendingEspbFormsUseCase,
       _syncEspbFormUseCase = syncEspbFormUseCase,
       _getEspbFormUseCase = getEspbFormUseCase {
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
      AppLogger.info('Network connection restored, triggering ESPB form sync');
      syncAllPendingForms();
    }
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      syncAllPendingForms(silent: true);
    });
  }

  /// Check if a form is synced
  Future<bool> isFormSynced(String noSpb) async {
    final result = await _getEspbFormUseCase(noSpb);
    return result.fold(
      (failure) => false,
      (formData) => formData?.isSynced ?? false,
    );
  }

  /// Sync a specific form with retry logic
  Future<bool> syncForm(String noSpb, {int retryCount = 0}) async {
    if (!_isConnected) {
      return false;
    }

    final result = await _syncEspbFormUseCase(noSpb);
    
    return result.fold(
      (failure) async {
        AppLogger.error('Error syncing form $noSpb (attempt ${retryCount + 1}): ${failure.message}');
        
        // Retry for certain error types
        if (failure is NetworkFailure || failure is TimeoutFailure) {
          if (retryCount < maxRetries) {
            final backoff = initialBackoff * pow(2, retryCount);
            AppLogger.info(
              'Retrying sync for SPB: $noSpb in ${backoff.inSeconds} seconds (attempt ${retryCount + 1}/$maxRetries)',
            );
            await Future.delayed(backoff);
            return syncForm(noSpb, retryCount: retryCount + 1);
          }
        }
        
        return false;
      },
      (success) => success,
    );
  }

  /// Sync all pending forms
  Future<bool> syncAllPendingForms({bool silent = false}) async {
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
      final result = await _syncAllPendingEspbFormsUseCase();
      
      return result.fold(
        (failure) {
          if (!silent) {
            syncStatusNotifier.value = SyncStatus.failed;
            errorMessageNotifier.value = failure.message;
          }
          _isSyncing = false;
          return false;
        },
        (successCount) {
          if (!silent) {
            syncStatusNotifier.value = SyncStatus.success;
            errorMessageNotifier.value = null;
            lastSyncTimeNotifier.value = DateTime.now();
          }
          _isSyncing = false;
          return successCount > 0;
        },
      );
    } catch (e) {
      AppLogger.error('Error syncing all pending forms: $e');
      if (!silent) {
        syncStatusNotifier.value = SyncStatus.failed;
        errorMessageNotifier.value = e.toString();
      }
      _isSyncing = false;
      return false;
    }
  }

  /// Force sync now
  Future<bool> forceSyncNow() async {
    return await syncAllPendingForms();
  }

  /// Get sync statistics
  Future<SyncStats> getSyncStats() async {
    int syncedCount = 0;
    int pendingCount = 0;
    int failedCount = 0;

    try {
      final result = await _syncAllPendingEspbFormsUseCase();
      
      result.fold(
        (failure) {
          // If we can't get stats, return zeros
        },
        (successCount) {
          // This is just the number of successfully synced forms in this run
          // We need to query the database for actual counts
        },
      );
      
      // In a real implementation, you would query the database for these counts
      
      return SyncStats(
        totalForms: syncedCount + pendingCount + failedCount,
        syncedForms: syncedCount,
        pendingForms: pendingCount,
        failedCount: failedCount,
      );
    } catch (e) {
      AppLogger.error('Error getting sync stats: $e');
      return SyncStats(
        totalForms: 0,
        syncedForms: 0,
        pendingForms: 0,
        failedCount: 0,
      );
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