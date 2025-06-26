import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';
import 'jwt_decoder_util.dart';

/// Manages JWT tokens with secure storage and data extraction
class JwtTokenManager {
  final FlutterSecureStorage _secureStorage;

  const JwtTokenManager(this._secureStorage);

  /// Stores a JWT token securely and extracts user data
  Future<Map<String, dynamic>?> storeAndExtractToken(String token) async {
    try {
      // Validate token before storing
      if (!JwtDecoderUtil.isTokenValid(token)) {
        AppLogger.warning('Attempting to store invalid JWT token');
        return null;
      }

      // Store the token securely
      await _secureStorage.write(key: StorageKeys.accessToken, value: token);

      // Extract and return filtered data
      final filteredData = JwtDecoderUtil.decodeAndFilterToken(token);

      if (filteredData != null) {
        AppLogger.info('JWT token stored and data extracted successfully');

        // Optionally store extracted user data separately for quick access
        final userInfo = JwtDecoderUtil.extractUserInfo(token);
        if (userInfo != null) {
          await _secureStorage.write(
            key: 'user_info',
            value: jsonEncode(userInfo),
          );
        }
      }

      return filteredData;
    } catch (e) {
      AppLogger.error('Failed to store and extract JWT token: $e');
      return null;
    }
  }

  /// Retrieves stored token and extracts current user data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      // First try to get from cached user info for better performance
      final userInfoJson = await _secureStorage.read(key: 'user_info');
      if (userInfoJson != null) {
        try {
          return jsonDecode(userInfoJson) as Map<String, dynamic>;
        } catch (e) {
          // If parsing fails, continue to token-based extraction
          AppLogger.warning(
            'Failed to parse cached user info, falling back to token extraction',
          );
        }
      }

      // Get from token if cache not available
      final token = await _secureStorage.read(key: StorageKeys.accessToken);
      if (token == null) {
        AppLogger.debug('No stored JWT token found');
        return null;
      }

      // Check if token is still valid
      if (!JwtDecoderUtil.isTokenValid(token)) {
        AppLogger.warning('Stored JWT token is expired');
        await clearStoredToken(); // Clean up expired token
        return null;
      }

      // Extract user info and update cache
      final userInfo = JwtDecoderUtil.extractUserInfo(token);
      if (userInfo != null) {
        // Update cached user info
        await _secureStorage.write(
          key: 'user_info',
          value: jsonEncode(userInfo),
        );
      }

      return userInfo;
    } catch (e) {
      AppLogger.error('Failed to get current user data: $e');
      return null;
    }
  }

  /// Gets token metadata without exposing sensitive data
  Future<Map<String, dynamic>?> getTokenMetadata() async {
    try {
      final token = await _secureStorage.read(key: StorageKeys.accessToken);
      if (token == null) return null;

      return JwtDecoderUtil.getTokenMetadata(token);
    } catch (e) {
      AppLogger.error('Failed to get token metadata: $e');
      return null;
    }
  }

  /// Extracts custom claims from stored token
  Future<Map<String, dynamic>?> getCustomClaims() async {
    try {
      final token = await _secureStorage.read(key: StorageKeys.accessToken);
      if (token == null) return null;

      return JwtDecoderUtil.extractCustomClaims(token);
    } catch (e) {
      AppLogger.error('Failed to get custom claims: $e');
      return null;
    }
  }

  /// Checks if stored token has specific claims
  Future<bool> hasRequiredClaims(List<String> requiredClaims) async {
    try {
      final token = await _secureStorage.read(key: StorageKeys.accessToken);
      if (token == null) return false;

      return JwtDecoderUtil.hasClaimsInToken(token, requiredClaims);
    } catch (e) {
      AppLogger.error('Failed to check required claims: $e');
      return false;
    }
  }

  /// Gets specific claims from stored token
  Future<Map<String, dynamic>> getSpecificClaims(
    List<String> claimNames,
  ) async {
    try {
      final token = await _secureStorage.read(key: StorageKeys.accessToken);
      if (token == null) return {};

      return JwtDecoderUtil.extractSpecificClaims(token, claimNames);
    } catch (e) {
      AppLogger.error('Failed to get specific claims: $e');
      return {};
    }
  }

  /// Clears stored token and user data
  Future<void> clearStoredToken() async {
    try {
      await _secureStorage.delete(key: StorageKeys.accessToken);
      await _secureStorage.delete(key: 'user_info');
      await _secureStorage.delete(key: StorageKeys.userCredentials);
      await _secureStorage.delete(key: StorageKeys.sessionData);

      // Clear any other token-related data
      final keys = await _secureStorage.readAll();
      for (final key in keys.keys) {
        if (key.startsWith('token_') || key.startsWith('auth_')) {
          await _secureStorage.delete(key: key);
        }
      }

      AppLogger.info('JWT token and user data cleared');
    } catch (e) {
      AppLogger.error('Failed to clear stored token: $e');

      // Try alternative approach if the first method fails
      try {
        await _secureStorage.deleteAll();
        AppLogger.info('Deleted all secure storage as fallback');
      } catch (e2) {
        AppLogger.error('Failed to delete all secure storage: $e2');
      }
    }
  }

  /// Refreshes user data from current token
  Future<Map<String, dynamic>?> refreshUserData() async {
    try {
      final token = await _secureStorage.read(key: StorageKeys.accessToken);
      if (token == null) return null;

      final userInfo = JwtDecoderUtil.extractUserInfo(token);
      if (userInfo != null) {
        // Update stored user info
        await _secureStorage.write(
          key: 'user_info',
          value: jsonEncode(userInfo),
        );
      }

      return userInfo;
    } catch (e) {
      AppLogger.error('Failed to refresh user data: $e');
      return null;
    }
  }

  /// Gets cached user info (faster than decoding token each time)
  Future<Map<String, dynamic>?> getCachedUserInfo() async {
    try {
      final userInfoJson = await _secureStorage.read(key: 'user_info');
      if (userInfoJson == null) return null;

      return jsonDecode(userInfoJson) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Failed to get cached user info: $e');
      // Fallback to extracting from token
      return getCurrentUserData();
    }
  }

  /// Checks if token is about to expire (within 5 minutes)
  Future<bool> isTokenExpiringSoon() async {
    try {
      final token = await _secureStorage.read(key: StorageKeys.accessToken);
      if (token == null) return true; // No token means we need to login

      final metadata = JwtDecoderUtil.getTokenMetadata(token);
      if (metadata == null) return true;

      final timeUntilExpiration = metadata['timeUntilExpiration'] as int?;
      if (timeUntilExpiration == null) return true;

      // Check if token expires in less than 5 minutes (300 seconds)
      return timeUntilExpiration < 300;
    } catch (e) {
      AppLogger.error('Failed to check token expiration: $e');
      return true; // Assume token is expiring to be safe
    }
  }

  /// Get the access token
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: StorageKeys.accessToken);
    } catch (e) {
      AppLogger.error('Failed to get access token: $e');
      return null;
    }
  }
}