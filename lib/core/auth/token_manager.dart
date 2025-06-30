import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../constants/storage_keys.dart';
import '../error/exceptions.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';
import '../di/injection.dart';
import '../storage/database_helper.dart';

/// Manages authentication tokens with refresh capability
class TokenManager {
  final SecureStorage _secureStorage;
  final DatabaseHelper _dbHelper;

  // Token expiration thresholds
  static const int _accessTokenExpiryMinutes = 30; // 30 minutes
  static const int _refreshTokenExpiryDays = 30; // 30 days

  // Refresh token before it expires (5 minutes)
  static const int _refreshBeforeExpiryMinutes = 5;

  // Rate limiting
  static const int _maxRefreshAttempts = 5;
  static const Duration _refreshLockoutDuration = Duration(minutes: 15);

  // Refresh attempt tracking
  final Map<String, int> _refreshAttempts = {};
  final Map<String, DateTime> _refreshLockouts = {};

  // Token change notifiers
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRefreshing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> authError = ValueNotifier<String?>(null);

  TokenManager(this._secureStorage, this._dbHelper);

  /// Stores access and refresh tokens securely
  Future<void> storeTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String username,
  }) async {
    try {
      // Store tokens in secure storage
      await _secureStorage.write(StorageKeys.accessToken, accessToken);
      await _secureStorage.write(StorageKeys.refreshToken, refreshToken);

      // Extract expiration times
      final accessTokenData = JwtDecoder.decode(accessToken);
      final refreshTokenData = JwtDecoder.decode(refreshToken);

      final accessTokenExpiry = accessTokenData['exp'] as int?;
      final refreshTokenExpiry = refreshTokenData['exp'] as int?;

      // Store tokens in database for offline access
      await _dbHelper.saveAuthToken(
        userId,
        username,
        accessToken,
        expiresAt: accessTokenExpiry,
      );

      // Store refresh token separately
      await _secureStorage.write(
        '${StorageKeys.refreshToken}_expiry',
        refreshTokenExpiry?.toString() ?? '',
      );

      // Store user info for quick access
      final userInfo = {
        'userId': userId,
        'username': username,
        'lastAuthenticated': DateTime.now().toIso8601String(),
      };
      await _secureStorage.write(
        StorageKeys.userCredentials,
        jsonEncode(userInfo),
      );

      // Update authentication state
      isAuthenticated.value = true;
      authError.value = null;

      AppLogger.info('Tokens stored successfully for user: $username');
    } catch (e) {
      AppLogger.error('Failed to store tokens: $e');
      authError.value = 'Failed to store authentication tokens';
      throw AuthException('Failed to store tokens: $e');
    }
  }

  /// Gets the current access token, refreshing if needed
  Future<String?> getAccessToken({bool autoRefresh = true}) async {
    try {
      final accessToken = await _secureStorage.read(StorageKeys.accessToken);

      // If no token, we're not authenticated
      if (accessToken == null) {
        isAuthenticated.value = false;
        return null;
      }

      // Check if token is expired or about to expire
      if (_isTokenExpiredOrExpiring(accessToken) && autoRefresh) {
        // Try to refresh the token
        return await refreshToken();
      }

      isAuthenticated.value = true;
      return accessToken;
    } catch (e) {
      AppLogger.error('Error getting access token: $e');
      return null;
    }
  }

  /// Gets the current refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(StorageKeys.refreshToken);
    } catch (e) {
      AppLogger.error('Error getting refresh token: $e');
      return null;
    }
  }

  /// Refreshes the access token using the refresh token
  Future<String?> refreshToken() async {
    // Check if we're already refreshing
    if (isRefreshing.value) {
      // Wait for the current refresh to complete
      int attempts = 0;
      while (isRefreshing.value && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }

      // If still refreshing after waiting, something is wrong
      if (isRefreshing.value) {
        authError.value = 'Token refresh is taking too long';
        return null;
      }

      // Return the refreshed token
      return await _secureStorage.read(StorageKeys.accessToken);
    }

    isRefreshing.value = true;
    authError.value = null;

    try {
      // Get user info
      final userInfoJson = await _secureStorage.read(
        StorageKeys.userCredentials,
      );
      if (userInfoJson == null) {
        throw AuthException('User credentials not found');
      }

      final userInfo = jsonDecode(userInfoJson) as Map<String, dynamic>;
      final username = userInfo['username'] as String;

      // Check rate limiting
      if (_isRateLimited(username)) {
        throw RateLimitException(
          'Too many refresh attempts. Please try again later.',
          retryAfterSeconds: _getRemainingLockoutSeconds(username),
        );
      }

      // Get refresh token
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        throw AuthException('Refresh token not found');
      }

      // Check if refresh token is expired
      if (_isTokenExpired(refreshToken)) {
        throw AuthException('Refresh token has expired. Please log in again.');
      }

      // Call API to refresh token (this would be implemented in an API service)
      // For now, we'll simulate a successful refresh with a new token
      final newTokens = await _callRefreshTokenApi(refreshToken);

      // Store new tokens
      await storeTokens(
        accessToken: newTokens['accessToken']!,
        refreshToken: newTokens['refreshToken']!,
        userId: userInfo['userId'],
        username: username,
      );

      // Reset refresh attempts on success
      _refreshAttempts.remove(username);

      AppLogger.info('Token refreshed successfully for user: $username');
      return newTokens['accessToken'];
    } catch (e) {
      // Handle specific exceptions
      if (e is AuthException) {
        authError.value = e.message;
        isAuthenticated.value = false;
      } else if (e is RateLimitException) {
        authError.value = e.message;
      } else if (e is NetworkException) {
        authError.value = 'Network error during token refresh';
      } else {
        authError.value = 'Failed to refresh token: ${e.toString()}';
        _incrementRefreshAttempt(await _getCurrentUsername());
      }

      AppLogger.error('Token refresh failed: $e');
      return null;
    } finally {
      isRefreshing.value = false;
    }
  }

  /// Validates a token when transitioning from offline to online
  Future<bool> validateTokenOnReconnect() async {
    try {
      final accessToken = await _secureStorage.read(StorageKeys.accessToken);
      if (accessToken == null) {
        return false;
      }

      // If token is not expired, it's still valid
      if (!_isTokenExpired(accessToken)) {
        return true;
      }

      // If token is expired, try to refresh
      final refreshedToken = await refreshToken();
      return refreshedToken != null;
    } catch (e) {
      AppLogger.error('Error validating token on reconnect: $e');
      return false;
    }
  }

  /// Clears all stored tokens and authentication state
  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(StorageKeys.accessToken);
      await _secureStorage.delete(StorageKeys.refreshToken);
      await _secureStorage.delete('${StorageKeys.refreshToken}_expiry');
      await _secureStorage.delete(StorageKeys.userCredentials);

      // Update authentication state
      isAuthenticated.value = false;
      authError.value = null;

      AppLogger.info('Tokens cleared successfully');
    } catch (e) {
      AppLogger.error('Failed to clear tokens: $e');
      throw AuthException('Failed to clear tokens: $e');
    }
  }

  /// Rotates the refresh token for security
  Future<void> rotateRefreshToken() async {
    try {
      // Get current refresh token
      final currentRefreshToken = await getRefreshToken();
      if (currentRefreshToken == null) {
        throw AuthException('No refresh token to rotate');
      }

      // Call API to rotate refresh token
      final newTokens = await _callRefreshTokenApi(currentRefreshToken);

      // Get user info
      final userInfoJson = await _secureStorage.read(
        StorageKeys.userCredentials,
      );
      if (userInfoJson == null) {
        throw AuthException('User credentials not found');
      }

      final userInfo = jsonDecode(userInfoJson) as Map<String, dynamic>;

      // Store new tokens
      await storeTokens(
        accessToken: newTokens['accessToken']!,
        refreshToken: newTokens['refreshToken']!,
        userId: userInfo['userId'],
        username: userInfo['username'],
      );

      AppLogger.info('Refresh token rotated successfully');
    } catch (e) {
      AppLogger.error('Failed to rotate refresh token: $e');
      throw AuthException('Failed to rotate refresh token: $e');
    }
  }

  /// Checks if a token is expired
  bool _isTokenExpired(String token) {
    try {
      return JwtDecoder.isExpired(token);
    } catch (e) {
      // If we can't decode the token, consider it expired
      return true;
    }
  }

  /// Checks if a token is expired or about to expire
  bool _isTokenExpiredOrExpiring(String token) {
    try {
      if (JwtDecoder.isExpired(token)) {
        return true;
      }

      // Check if token will expire soon
      final expirationDate = JwtDecoder.getExpirationDate(token);
      final now = DateTime.now();
      final timeUntilExpiry = expirationDate.difference(now);

      return timeUntilExpiry.inMinutes <= _refreshBeforeExpiryMinutes;
    } catch (e) {
      // If we can't decode the token, consider it expired
      return true;
    }
  }

  /// Simulates calling an API to refresh the token
  /// In a real app, this would make an HTTP request to your auth server
  Future<Map<String, String>> _callRefreshTokenApi(String refreshToken) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // In a real app, you would call your auth API here
    // For now, we'll generate new tokens with future expiration dates

    // Create a new access token that expires in 30 minutes
    final accessTokenExpiry = DateTime.now().add(
      Duration(minutes: _accessTokenExpiryMinutes),
    );
    final accessTokenPayload = {
      'sub': 'user123',
      'username': await _getCurrentUsername(),
      'exp': accessTokenExpiry.millisecondsSinceEpoch ~/ 1000,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    // Create a new refresh token that expires in 30 days
    final refreshTokenExpiry = DateTime.now().add(
      Duration(days: _refreshTokenExpiryDays),
    );
    final refreshTokenPayload = {
      'sub': 'user123',
      'exp': refreshTokenExpiry.millisecondsSinceEpoch ~/ 1000,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    // In a real app, these would be signed by your auth server
    // Here we're just base64 encoding them for simulation
    final accessToken = _encodeToken(accessTokenPayload);
    final newRefreshToken = _encodeToken(refreshTokenPayload);

    return {'accessToken': accessToken, 'refreshToken': newRefreshToken};
  }

  /// Simple token encoding for simulation purposes
  /// In a real app, tokens would be signed by your auth server
  String _encodeToken(Map<String, dynamic> payload) {
    final header = base64Encode(
      utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
    );
    final encodedPayload = base64Encode(utf8.encode(jsonEncode(payload)));
    final signature = base64Encode(utf8.encode('signature')); // Fake signature

    return '$header.$encodedPayload.$signature';
  }

  /// Gets the current username from stored credentials
  Future<String> _getCurrentUsername() async {
    try {
      final userInfoJson = await _secureStorage.read(
        StorageKeys.userCredentials,
      );
      if (userInfoJson == null) {
        return '';
      }

      final userInfo = jsonDecode(userInfoJson) as Map<String, dynamic>;
      return userInfo['username'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Increments the refresh attempt counter for rate limiting
  void _incrementRefreshAttempt(String username) {
    if (username.isEmpty) return;

    _refreshAttempts[username] = (_refreshAttempts[username] ?? 0) + 1;

    // If too many attempts, lock the account
    if (_refreshAttempts[username]! >= _maxRefreshAttempts) {
      _refreshLockouts[username] = DateTime.now().add(_refreshLockoutDuration);
      AppLogger.warning(
        'Rate limit exceeded for user: $username. Locked out for $_refreshLockoutDuration',
      );
    }
  }

  /// Checks if a user is rate limited for token refreshes
  bool _isRateLimited(String username) {
    if (username.isEmpty) return false;

    // Check if user is in lockout period
    final lockoutUntil = _refreshLockouts[username];
    if (lockoutUntil != null && lockoutUntil.isAfter(DateTime.now())) {
      return true;
    }

    // If lockout has expired, remove it
    if (lockoutUntil != null) {
      _refreshLockouts.remove(username);
      _refreshAttempts.remove(username);
    }

    return false;
  }

  /// Gets the remaining lockout time in seconds
  int _getRemainingLockoutSeconds(String username) {
    final lockoutUntil = _refreshLockouts[username];
    if (lockoutUntil == null) return 0;

    final remaining = lockoutUntil.difference(DateTime.now());
    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }

  /// Logs authentication events for security monitoring
  void _logAuthEvent(String event, {String? username, String? error}) {
    final logData = {
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
      'username': username,
      'error': error,
    };

    AppLogger.info('Auth event: ${jsonEncode(logData)}');

    // In a real app, you might send this to a logging service
    // or store it in a local database for security auditing
  }
}
