import 'dart:async';
import 'package:flutter/foundation.dart';
import '../storage/user_profile_repository.dart';
import '../services/connectivity_service.dart';
import '../utils/logger.dart';
import '../di/injection.dart';

class SyncService {
  final UserProfileRepository _userProfileRepository;
  final ConnectivityService _connectivityService;

  // Sync status notifier
  final syncStatusNotifier = ValueNotifier<SyncStatus>(SyncStatus.idle);

  // Sync error notifier
  final syncErrorNotifier = ValueNotifier<String?>(null);

  // Last sync time
  final lastSyncTimeNotifier = ValueNotifier<DateTime?>(null);

  // Sync in progress flag
  bool _isSyncing = false;

  // Background sync timer
  Timer? _backgroundSyncTimer;

  // Connectivity subscription
  StreamSubscription? _connectivitySubscription;

  SyncService({
    required UserProfileRepository userProfileRepository,
    required ConnectivityService connectivityService,
  }) : _userProfileRepository = userProfileRepository,
       _connectivityService = connectivityService {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen(_handleConnectivityChange);

    // Start background sync timer
    _startBackgroundSync();
  }

  // Handle connectivity changes
  void _handleConnectivityChange(ConnectivityStatus status) {
    if (status == ConnectivityStatus.connected) {
      // When connection is restored, try to sync
      syncUserProfile();
    }
  }

  // Start background sync timer
  void _startBackgroundSync() {
    // Cancel existing timer if any
    _backgroundSyncTimer?.cancel();
    // Start new timer (every 15 minutes)
    _backgroundSyncTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _backgroundSync(),
    );
  }

  // Background sync operation
  Future<void> _backgroundSync() async {
    try {
      // Skip if already syncing or no connectivity
      if (_isSyncing || !_connectivityService.isConnected) {
        return;
      }

      // Process sync queue
      await processSyncQueue();

      // Get token to check if we're logged in
      final token = await _userProfileRepository.getAccessToken();
      if (token == null) {
        return; // Not logged in
      }
      // Sync user profile
      await syncUserProfile(silent: true);
    } catch (e) {
      AppLogger.error('Background sync failed: $e');
    }
  }

  // Sync user profile
  Future<bool> syncUserProfile({bool silent = false}) async {
    // Skip if already syncing
    if (_isSyncing) {
      return false;
    }

    try {
      _isSyncing = true;

      if (!silent) {
        syncStatusNotifier.value = SyncStatus.syncing;
      }

      // Get token to check if we're logged in
      final token = await _userProfileRepository.getAccessToken();
      if (token == null) {
        if (!silent) {
          syncStatusNotifier.value = SyncStatus.failed;
          // syncErrorNotifier.value = 'Not authenticated';
        }
        return false;
      }

      // Get user data from token
      final userInfo = await _userProfileRepository.getUserProfile(
        forceRefresh: true,
      );

      return await userInfo.fold(
        (failure) {
          if (!silent) {
            syncStatusNotifier.value = SyncStatus.failed;
            syncErrorNotifier.value = failure.message;
          }
          return false;
        },
        (userData) async {
          // Update last sync time
          lastSyncTimeNotifier.value = DateTime.now();
          if (!silent) {
            syncStatusNotifier.value = SyncStatus.success;
            syncErrorNotifier.value = null;
          }
          return true;
        },
      );
    } catch (e) {
      AppLogger.error('Sync user profile failed: $e');
      if (!silent) {
        syncStatusNotifier.value = SyncStatus.failed;
        syncErrorNotifier.value = e.toString();
      }
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // Process sync queue
  Future<bool> processSyncQueue() async {
    try {
      // Skip if no connectivity
      if (!_connectivityService.isConnected) {
        return false;
      }

      // Process sync queue
      final result = await _userProfileRepository.processSyncQueue();

      return result.fold(
        (failure) {
          AppLogger.error('Process sync queue failed: ${failure.message}');
          return false;
        },
        (count) {
          if (count > 0) {
            AppLogger.info('Processed $count sync queue items');
          }
          return count > 0;
        },
      );
    } catch (e) {
      AppLogger.error('Process sync queue failed: $e');
      return false;
    }
  }

  // Force sync now
  Future<bool> forceSyncNow() async {
    return await syncUserProfile();
  }

  void dispose() {
    syncErrorNotifier.dispose();
    lastSyncTimeNotifier.dispose();
  }
}

// Sync status enum
enum SyncStatus { idle, syncing, success, failed }