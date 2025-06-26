import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../error/failures.dart';
import '../storage/secure_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/refresh_token_usecase.dart';
import 'dart:async';
import 'dart:convert';
import '../../core/storage/database_helper.dart';
import '../../../../core/di/injection.dart';
import '../../core/storage/secure_storage.dart';

enum AuthSyncStatus { idle, syncing, success, failed, offline }

class AuthSyncService {
  final AuthRepository _authRepository;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final Connectivity _connectivity;
  final SecureStorage _secureStorage;

  // Status notifiers
  final ValueNotifier<AuthSyncStatus> syncStatusNotifier =
      ValueNotifier<AuthSyncStatus>(AuthSyncStatus.idle);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<DateTime?> lastSyncTimeNotifier =
      ValueNotifier<DateTime?>(null);

  // Sync configuration
  final Duration _syncInterval;
  final Duration _initialBackoffDuration;
  final int _maxRetryAttempts;

  // Internal state
  bool _isSyncing = false;
  Timer? _syncTimer;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  StreamSubscription? _connectivitySubscription;
  bool _isConnected = false;

  AuthSyncService({
    required AuthRepository authRepository,
    required RefreshTokenUseCase refreshTokenUseCase,
    required Connectivity connectivity,
    required SecureStorage secureStorage,
    Duration? syncInterval,
    Duration? initialBackoffDuration,
    int? maxRetryAttempts,
  }) : _authRepository = authRepository,
       _refreshTokenUseCase = refreshTokenUseCase,
       _connectivity = connectivity,
       _secureStorage = secureStorage,
       _syncInterval = syncInterval ?? const Duration(minutes: 15),
       _initialBackoffDuration =
           initialBackoffDuration ?? const Duration(seconds: 5),
       _maxRetryAttempts = maxRetryAttempts ?? 5 {
    // Initialize connectivity monitoring
    _initConnectivityMonitoring();

    // Start periodic sync
    _startPeriodicSync();
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
      AppLogger.info('Network connection restored, triggering auth sync');
      _syncAuthStatus();
    }

    // Update status if we're offline
    if (!_isConnected && syncStatusNotifier.value != AuthSyncStatus.offline) {
      syncStatusNotifier.value = AuthSyncStatus.offline;
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      _syncAuthStatus();
    });

    // Perform initial sync
    _syncAuthStatus();
  }

  /// Sync authentication status with server
  Future<void> _syncAuthStatus() async {
    // Skip if already syncing or offline
    if (_isSyncing || !_isConnected) {
      return;
    }

    _isSyncing = true;
    _retryAttempt = 0;

    try {
      syncStatusNotifier.value = AuthSyncStatus.syncing;
      errorMessageNotifier.value = null;

      // Check if user is logged in
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (!isLoggedIn) {
        // Not logged in, nothing to sync
        syncStatusNotifier.value = AuthSyncStatus.idle;
        _isSyncing = false;
        return;
      }

      // Validate token with server
      final result = await _refreshTokenUseCase.validateToken();

      await result.fold(
        (failure) async {
          // Token validation failed
          if (failure is AuthFailure) {
            // Token is invalid or expired
            AppLogger.warning(
              'Auth token validation failed: ${failure.message}',
            );
            errorMessageNotifier.value =
                'Authentication expired. Please log in again.';
            syncStatusNotifier.value = AuthSyncStatus.failed;

            // Clear invalid token
            await _secureStorage.delete(StorageKeys.accessToken);
          } else if (failure is NetworkFailure || failure is TimeoutFailure) {
            // Network issue, schedule retry with backoff
            AppLogger.warning(
              'Network error during auth sync: ${failure.message}',
            );
            _scheduleRetry();
          } else {
            // Other error
            AppLogger.error('Error during auth sync: ${failure.message}');
            errorMessageNotifier.value = failure.message;
            syncStatusNotifier.value = AuthSyncStatus.failed;
          }
        },
        (isValid) async {
          // Token is valid
          if (isValid) {
            AppLogger.info('Auth token validated successfully');
            lastSyncTimeNotifier.value = DateTime.now();
            syncStatusNotifier.value = AuthSyncStatus.success;

            // Process any queued auth requests
            await _processAuthQueue();
          } else {
            // Token is invalid
            AppLogger.warning('Auth token is invalid');
            errorMessageNotifier.value =
                'Authentication expired. Please log in again.';
            syncStatusNotifier.value = AuthSyncStatus.failed;

            // Clear invalid token
            await _secureStorage.delete(StorageKeys.accessToken);
          }
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error during auth sync: $e');
      errorMessageNotifier.value =
          'Unexpected error during authentication sync';
      syncStatusNotifier.value = AuthSyncStatus.failed;

      // Schedule retry
      _scheduleRetry();
    } finally {
      _isSyncing = false;
    }
  }

  /// Schedule a retry with exponential backoff
  void _scheduleRetry() {
    if (_retryAttempt >= _maxRetryAttempts) {
      AppLogger.warning('Max retry attempts reached for auth sync');
      return;
    }

    _retryTimer?.cancel();

    // Calculate backoff duration with exponential increase
    final backoffDuration = _initialBackoffDuration * (1 << _retryAttempt);
    AppLogger.info(
      'Scheduling auth sync retry in ${backoffDuration.inSeconds} seconds (attempt ${_retryAttempt + 1}/${_maxRetryAttempts})',
    );

    _retryTimer = Timer(backoffDuration, () {
      _retryAttempt++;
      _syncAuthStatus();
    });
  }

  /// Process queued authentication requests
  Future<void> _processAuthQueue() async {
    try {
      // Get the database helper
      final dbHelper = getIt<DatabaseHelper>();

      // Get pending auth sync items
      final pendingItems = await dbHelper.getPendingAuthSyncItems();

      if (pendingItems.isEmpty) {
        return;
      }

      AppLogger.info(
        'Processing ${pendingItems.length} pending auth sync items',
      );

      for (final item in pendingItems) {
        try {
          final operation = item['operation'] as String;
          final data =
              jsonDecode(item['data'] as String) as Map<String, dynamic>;

          if (operation == 'change_password') {
            // Process password change
            final result = await _authRepository.changePassword(
              data['currentPassword'] as String,
              data['newPassword'] as String,
            );

            await result.fold(
              (failure) async {
                // Update retry count
                await dbHelper.updateAuthSyncItem(item['id'] as int, {
                  'retry_count': (item['retry_count'] as int) + 1,
                  'last_error': failure.message,
                  'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  'status':
                      (item['retry_count'] as int) >= _maxRetryAttempts
                          ? 'failed'
                          : 'pending',
                });
              },
              (_) async {
                // Success, remove from queue
                await dbHelper.removeAuthSyncItem(item['id'] as int);
              },
            );
          }
          // Add other auth operations as needed
        } catch (e) {
          AppLogger.error('Error processing auth sync item: $e');

          // Update retry count
          await dbHelper.updateAuthSyncItem(item['id'] as int, {
            'retry_count': (item['retry_count'] as int) + 1,
            'last_error': e.toString(),
            'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'status':
                (item['retry_count'] as int) >= _maxRetryAttempts
                    ? 'failed'
                    : 'pending',
          });
        }
      }
    } catch (e) {
      AppLogger.error('Error processing auth sync queue: $e');
    }
  }

  /// Add an authentication operation to the sync queue
  Future<void> addToAuthQueue(
    String operation,
    Map<String, dynamic> data,
  ) async {
    try {
      final dbHelper = getIt<DatabaseHelper>();

      await dbHelper.addToAuthSyncQueue(operation, data);

      AppLogger.info('Added $operation to auth sync queue');

      // Try to process immediately if online
      if (_isConnected) {
        _syncAuthStatus();
      }
    } catch (e) {
      AppLogger.error('Failed to add to auth sync queue: $e');
    }
  }

  /// Force sync now
  Future<bool> forceSyncNow() async {
    if (_isSyncing || !_isConnected) {
      return false;
    }

    await _syncAuthStatus();
    return syncStatusNotifier.value == AuthSyncStatus.success;
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    syncStatusNotifier.dispose();
    errorMessageNotifier.dispose();
    lastSyncTimeNotifier.dispose();
  }
}
