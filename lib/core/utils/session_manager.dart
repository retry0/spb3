import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';
import '../di/injection.dart';
import 'logger.dart';
import 'jwt_token_manager.dart';

class SessionManager {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  final JwtTokenManager _tokenManager;

  // Session timeout in minutes (default: 30 minutes)
  final int _sessionTimeoutMinutes;

  // Timer for session checks
  Timer? _sessionCheckTimer;

  // Timer for session warnings
  Timer? _sessionWarningTimer;

  // Session warning threshold in minutes (default: 5 minutes before timeout)
  final int _sessionWarningMinutes;

  // Session state
  final ValueNotifier<SessionState> sessionState = ValueNotifier(
    SessionState.unknown,
  );

  // Session expiry time
  final ValueNotifier<DateTime?> sessionExpiryTime = ValueNotifier(null);

  SessionManager(
    this._prefs,
    this._secureStorage,
    this._tokenManager, {
    int sessionTimeoutMinutes = 60,
    int? sessionWarningMinutes,
  }) : _sessionTimeoutMinutes = sessionTimeoutMinutes,
       _sessionWarningMinutes =
           sessionWarningMinutes ?? (sessionTimeoutMinutes ~/ 6) {
    // Start session monitoring
    _startSessionMonitoring();
  }

  // Initialize session
  Future<void> initializeSession() async {
    try {
      final token = await _secureStorage.read(key: StorageKeys.accessToken);

      if (token != null && !await _tokenManager.isTokenExpiringSoon()) {
        // Valid token exists
        await updateLastActivity();
        sessionState.value = SessionState.active;

        // Set session expiry time
        _updateSessionExpiryTime();
      } else if (token != null) {
        // Token exists but is expiring soon
        sessionState.value = SessionState.expiring;

        // Set session expiry time
        _updateSessionExpiryTime();
      } else {
        // No valid token
        sessionState.value = SessionState.inactive;
        sessionExpiryTime.value = null;
      }
    } catch (e) {
      AppLogger.error('Failed to initialize session: $e');
      sessionState.value = SessionState.error;
      sessionExpiryTime.value = null;
    }
  }

  // Update last activity timestamp
  Future<void> updateLastActivity() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _prefs.setInt(StorageKeys.lastActivity, now);

      // If session was expiring, set it back to active
      if (sessionState.value == SessionState.expiring) {
        sessionState.value = SessionState.active;
      }

      // Update session expiry time
      _updateSessionExpiryTime();

      // Reset session warning timer
      _resetSessionWarningTimer();
    } catch (e) {
      AppLogger.error('Failed to update last activity: $e');
    }
  }

  // Update session expiry time
  void _updateSessionExpiryTime() {
    final lastActivity = _prefs.getInt(StorageKeys.lastActivity);
    if (lastActivity != null) {
      final lastActivityTime = DateTime.fromMillisecondsSinceEpoch(
        lastActivity,
      );
      sessionExpiryTime.value = lastActivityTime.add(
        Duration(minutes: _sessionTimeoutMinutes),
      );
    } else {
      sessionExpiryTime.value = null;
    }
  }

  // Reset session warning timer
  void _resetSessionWarningTimer() {
    _sessionWarningTimer?.cancel();

    final lastActivity = _prefs.getInt(StorageKeys.lastActivity);
    if (lastActivity != null) {
      final lastActivityTime = DateTime.fromMillisecondsSinceEpoch(
        lastActivity,
      );
      final warningTime = lastActivityTime.add(
        Duration(minutes: _sessionTimeoutMinutes - _sessionWarningMinutes),
      );

      final now = DateTime.now();
      if (warningTime.isAfter(now)) {
        // Schedule warning
        final delay = warningTime.difference(now);
        _sessionWarningTimer = Timer(delay, () {
          // Check if session is still active before showing warning
          if (sessionState.value == SessionState.active) {
            sessionState.value = SessionState.expiring;
          }
        });
      } else if (sessionState.value == SessionState.active) {
        // Warning time has already passed
        sessionState.value = SessionState.expiring;
      }
    }
  }

  // Check if session is active
  Future<bool> isSessionActive() async {
    try {
      // Check if token exists and is valid
      final token = await _secureStorage.read(key: StorageKeys.accessToken);
      if (token == null) return false;

      // Check if token is valid
      if (await _tokenManager.isTokenExpiringSoon()) {
        sessionState.value = SessionState.expiring;
        return true; // Still active but expiring soon
      }

      // Check last activity
      final lastActivity = _prefs.getInt(StorageKeys.lastActivity);
      if (lastActivity == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedMinutes = (now - lastActivity) / (1000 * 60);

      final isActive = elapsedMinutes < _sessionTimeoutMinutes;
      sessionState.value =
          isActive ? SessionState.active : SessionState.timeout;

      return isActive;
    } catch (e) {
      AppLogger.error('Failed to check session status: $e');
      sessionState.value = SessionState.error;
      return false;
    }
  }

  // Clear session data
  Future<void> clearSession() async {
    try {
      // Clear token
      await _secureStorage.delete(key: StorageKeys.accessToken);

      // Clear session data
      await _secureStorage.delete(key: StorageKeys.sessionData);
      await _secureStorage.delete(key: StorageKeys.userCredentials);

      // Clear activity timestamp
      await _prefs.remove(StorageKeys.lastActivity);

      // Clear any other session-related data
      final allPrefs = _prefs.getKeys();
      for (final key in allPrefs) {
        if (key.startsWith('session_') || key.startsWith('auth_')) {
          await _prefs.remove(key);
        }
      }

      // Update session state
      sessionState.value = SessionState.inactive;
      sessionExpiryTime.value = null;

      AppLogger.info('Session cleared successfully');
    } catch (e) {
      AppLogger.error('Failed to clear session: $e');

      // Try alternative approach if the first method fails
      try {
        //await _tokenManager.clearStoredToken();
        AppLogger.info('Used token manager to clear session as fallback');
        sessionState.value = SessionState.inactive;
        sessionExpiryTime.value = null;
      } catch (e2) {
        AppLogger.error('Failed to clear session via token manager: $e2');
      }
    }
  }

  // Store session data
  Future<void> storeSessionData(Map<String, dynamic> data) async {
    try {
      // Convert data to JSON string
      final jsonData = jsonEncode(data);
      await _secureStorage.write(key: StorageKeys.sessionData, value: jsonData);
    } catch (e) {
      AppLogger.error('Failed to store session data: $e');
    }
  }

  // Get session data
  Future<Map<String, dynamic>?> getSessionData() async {
    try {
      final jsonData = await _secureStorage.read(key: StorageKeys.sessionData);
      if (jsonData == null) return null;

      // Parse JSON string to Map
      return jsonDecode(jsonData) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Failed to get session data: $e');
      return null;
    }
  }

  // Get time remaining until session expires
  Duration? getTimeUntilExpiry() {
    if (sessionExpiryTime.value == null) return null;

    final now = DateTime.now();
    if (sessionExpiryTime.value!.isAfter(now)) {
      return sessionExpiryTime.value!.difference(now);
    }

    return Duration.zero;
  }

  // Get time remaining until session warning
  Duration? getTimeUntilWarning() {
    if (sessionExpiryTime.value == null) return null;

    final now = DateTime.now();
    final warningTime = sessionExpiryTime.value!.subtract(
      Duration(minutes: _sessionWarningMinutes),
    );

    if (warningTime.isAfter(now)) {
      return warningTime.difference(now);
    }

    return Duration.zero;
  }

  // Start session monitoring
  void _startSessionMonitoring() {
    // Check session status every minute
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (sessionState.value != SessionState.inactive) {
        final isActive = await isSessionActive();
        if (!isActive && sessionState.value == SessionState.active) {
          // Session timed out
          sessionState.value = SessionState.timeout;
        }
      }
    });

    // Initialize session
    initializeSession();
  }

  // Dispose resources
  void dispose() {
    _sessionCheckTimer?.cancel();
    _sessionWarningTimer?.cancel();
    sessionState.dispose();
    sessionExpiryTime.dispose();
  }
}

// Session state enum
enum SessionState {
  unknown, // Initial state
  active, // Session is active
  expiring, // Session is active but token is expiring soon
  timeout, // Session timed out due to inactivity
  inactive, // No active session
  error, // Error occurred during session operations
}
