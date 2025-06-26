import 'dart:convert';

import '../constants/storage_keys.dart';
import '../error/exceptions.dart';
import '../utils/jwt_decoder_util.dart';
import '../utils/logger.dart';
import 'jwt_token_manager.dart';

/// Utility class for retrieving and validating user profile data
class UserProfileValidator {
  final JwtTokenManager _tokenManager;

  const UserProfileValidator(this._tokenManager);

  /// Retrieves and validates the user profile data and authentication token
  ///
  /// Returns a map containing the user profile data and token if valid
  /// Returns null if any data is missing or invalid
  Future<Map<String, dynamic>?> getValidUserProfile() async {
    try {
      // Get token and check validity
      final token = await _tokenManager.getStoredToken();
      if (token == null) {
        AppLogger.info('No stored token found');
        return null;
      }

      // Validate token
      if (!JwtDecoderUtil.isTokenValid(token)) {
        AppLogger.warning('Stored token is expired or invalid');
        await _clearInvalidData();
        return null;
      }

      // Get user data from token
      final userData = await _tokenManager.getCurrentUserData();
      if (userData == null || userData.isEmpty) {
        AppLogger.warning('No valid user data found in token');
        await _clearInvalidData();
        return null;
      }

      // Validate required user fields
      if (!_validateRequiredUserFields(userData)) {
        AppLogger.warning('User data is missing required fields');
        await _clearInvalidData();
        return null;
      }

      // Return validated data
      return {'userData': userData, 'token': token};
    } catch (e) {
      AppLogger.error('Error validating user profile', e);
      await _clearInvalidData();
      return null;
    }
  }

  /// Validates that the user data contains all required fields
  bool _validateRequiredUserFields(Map<String, dynamic> userData) {
    final requiredFields = ['id', 'userName', 'email', 'name'];

    for (final field in requiredFields) {
      if (!userData.containsKey(field) ||
          userData[field] == null ||
          userData[field].toString().isEmpty) {
        AppLogger.warning('Missing required user field: $field');
        return false;
      }
    }

    return true;
  }

  /// Clears invalid data from storage
  Future<void> _clearInvalidData() async {
    try {
      await _tokenManager.clearStoredToken();
      AppLogger.info('Cleared invalid user data and token');
    } catch (e) {
      AppLogger.error('Failed to clear invalid data', e);
    }
  }

  /// Gets the stored token
  Future<String?> getStoredToken() async {
    return await _tokenManager.getStoredToken();
  }
}

/// Extension for JwtTokenManager to add getStoredToken method
extension JwtTokenManagerExtension on JwtTokenManager {
  /// Gets the stored token without validation
  Future<String?> getStoredToken() async {
    try {
      return await secureStorage.read(key: StorageKeys.accessToken);
    } catch (e) {
      AppLogger.error('Failed to get stored token', e);
      return null;
    }
  }
}
