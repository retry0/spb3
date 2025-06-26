import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../../../core/storage/database_helper.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/utils/logger.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveToken(String token);
  Future<String?> getAccessToken();
  Future<void> clearToken();
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser(String userName);
  Future<UserModel?> getUserById(String userId);
  Future<void> updateUser(UserModel user);
  Future<void> deleteUser(String userName);
  Future<bool> isUserNameAvailable(String userName);
  
  // Offline authentication
  Future<void> saveOfflineCredentials(String userName, String password);
  Future<bool> verifyOfflineCredentials(String userName, String password);
  Future<void> updateLastOnlineAuth(String userName);
  Future<DateTime?> getLastOnlineAuth(String userName);
  
  // Token management
  Future<bool> isTokenExpired();
  Future<void> saveAuthTokenToDatabase(String userId, String userName, String token, {int? expiresAt});
  Future<Map<String, dynamic>?> getAuthTokenFromDatabase(String userName);
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SecureStorage _secureStorage;
  final DatabaseHelper _dbHelper;

  AuthLocalDataSourceImpl(this._secureStorage, this._dbHelper);

  @override
  Future<void> saveToken(String token) async {
    await _secureStorage.write(StorageKeys.accessToken, token);
    
    // Also save to SQLite for offline authentication
    try {
      // Skip for offline tokens
      if (token.startsWith('offline_')) {
        return;
      }
      
      // Extract user info from token
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      
      // Get user ID and username from token
      final userId = decodedToken['Id'] ?? decodedToken['sub'];
      final userName = decodedToken['UserName'];
      
      if (userId != null && userName != null) {
        // Calculate expiration time if available
        int? expiresAt;
        if (decodedToken.containsKey('exp')) {
          expiresAt = decodedToken['exp'];
        }
        
        // Save token to database
        await saveAuthTokenToDatabase(userId, userName, token, expiresAt: expiresAt);
        
        AppLogger.info('Token saved to database for offline authentication');
      }
    } catch (e) {
      AppLogger.error('Failed to save token to database', e);
      // Continue even if database save fails - we still have the token in secure storage
    }
  }

  @override
  Future<String?> getAccessToken() async {
    // First try to get from secure storage
    final token = await _secureStorage.read(StorageKeys.accessToken);
    
    // If token exists and is valid, return it
    if (token != null) {
      // Check if it's an offline token
      if (token.startsWith('offline_')) {
        return token;
      }
      
      // Check if regular JWT token is expired
      if (!JwtDecoder.isExpired(token)) {
        return token;
      }
    }
    
    // If token doesn't exist or is expired, try to get from database
    try {
      // Get current user from secure storage if available
      final userInfoJson = await _secureStorage.read('user_info');
      if (userInfoJson != null) {
        final userInfo = jsonDecode(userInfoJson) as Map<String, dynamic>;
        final userName = userInfo['UserName'];
        
        if (userName != null) {
          final tokenData = await getAuthTokenFromDatabase(userName);
          if (tokenData != null) {
            final dbToken = tokenData['token'] as String;
            
            // Check if token from database is valid
            final isOfflineToken = dbToken.startsWith('offline_');
            final isExpired = !isOfflineToken && JwtDecoder.isExpired(dbToken);
            
            if (isOfflineToken || !isExpired) {
              // Save to secure storage for future use
              await _secureStorage.write(StorageKeys.accessToken, dbToken);
              return dbToken;
            }
          }
        }
      }
      
      // Clean up expired tokens in the background
      _dbHelper.cleanupExpiredTokens();
      
      return null;
    } catch (e) {
      AppLogger.error('Failed to get token from database', e);
      return null;
    }
  }

  @override
  Future<void> clearToken() async {
    await _secureStorage.delete(StorageKeys.accessToken);
    
    // We don't delete tokens from the database to allow for offline login
    // They will be cleaned up by the expiration cleanup process
  }

  @override
  Future<void> saveUser(UserModel user) async {
    try {
      await _dbHelper.insert('users', user.toDatabase());
    } catch (e) {
      AppLogger.error('Failed to save user', e);
      rethrow;
    }
  }

  @override
  Future<UserModel?> getUser(String userName) async {
    try {
      final results = await _dbHelper.query(
        'users',
        where: 'UserName = ?',
        whereArgs: [userName],
        limit: 1,
      );

      if (results.isNotEmpty) {
        // Safely handle potential null values
        final data = results.first;
        
        // Ensure required fields are present
        if (data['id'] == null || data['UserName'] == null || data['Nama'] == null) {
          AppLogger.error('User data is missing required fields: $data');
          return null;
        }
        
        return UserModel(
          Id: data['id'] as String,
          UserName: data['UserName'] as String,
          Nama: data['Nama'] as String,
        );
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get user by userName', e);
      return null;
    }
  }

  @override
  Future<UserModel?> getUserById(String userId) async {
    try {
      final results = await _dbHelper.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        // Safely handle potential null values
        final data = results.first;
        
        // Ensure required fields are present
        if (data['id'] == null || data['UserName'] == null || data['Nama'] == null) {
          AppLogger.error('User data is missing required fields: $data');
          return null;
        }
        
        return UserModel(
          Id: data['id'] as String,
          UserName: data['UserName'] as String,
          Nama: data['Nama'] as String,
        );
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get user by ID', e);
      return null;
    }
  }

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      await _dbHelper.update(
        'users',
        user.toDatabase(),
        where: 'id = ?',
        whereArgs: [user.Id],
      );
    } catch (e) {
      AppLogger.error('Failed to update user', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(String userName) async {
    try {
      await _dbHelper.delete(
        'users',
        where: 'UserName = ?',
        whereArgs: [userName],
      );
    } catch (e) {
      AppLogger.error('Failed to delete user', e);
      rethrow;
    }
  }

  @override
  Future<bool> isUserNameAvailable(String userName) async {
    try {
      final results = await _dbHelper.query(
        'users',
        columns: ['id'],
        where: 'UserName = ?',
        whereArgs: [userName],
        limit: 1,
      );

      return results.isEmpty;
    } catch (e) {
      AppLogger.error('Failed to check userName availability', e);
      return false;
    }
  }
  
  // New methods for offline authentication
  
  @override
  Future<void> saveOfflineCredentials(String userName, String password) async {
    try {
      // Generate a random salt
      final salt = _generateSalt();
      
      // Hash the password with the salt
      final passwordHash = _hashPassword(password, salt);
      
      // Save to database
      await _dbHelper.saveUserCredentials(userName, passwordHash, salt);
      
      AppLogger.info('Offline credentials saved for: $userName');
    } catch (e) {
      AppLogger.error('Failed to save offline credentials', e);
      rethrow;
    }
  }
  
  @override
  Future<bool> verifyOfflineCredentials(String userName, String password) async {
    try {
      // Get stored credentials
      final credentials = await _dbHelper.getUserCredentials(userName);
      if (credentials == null) {
        return false;
      }
      
      // Get stored hash and salt
      final storedHash = credentials['password_hash'] as String;
      final salt = credentials['salt'] as String;
      
      // Hash the provided password with the stored salt
      final calculatedHash = _hashPassword(password, salt);
      
      // Compare hashes
      return storedHash == calculatedHash;
    } catch (e) {
      AppLogger.error('Failed to verify offline credentials', e);
      return false;
    }
  }
  
  @override
  Future<void> updateLastOnlineAuth(String userName) async {
    try {
      await _dbHelper.updateLastOnlineAuth(userName);
    } catch (e) {
      AppLogger.error('Failed to update last online auth timestamp', e);
      // Don't rethrow - this is a non-critical operation
    }
  }
  
  @override
  Future<DateTime?> getLastOnlineAuth(String userName) async {
    try {
      final credentials = await _dbHelper.getUserCredentials(userName);
      if (credentials != null && credentials['last_online_auth'] != null) {
        final timestamp = credentials['last_online_auth'] as int;
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get last online auth timestamp', e);
      return null;
    }
  }
  
  @override
  Future<bool> isTokenExpired() async {
    try {
      final token = await _secureStorage.read(StorageKeys.accessToken);
      if (token == null) {
        return true; // No token means it's expired
      }
      
      // Offline tokens don't expire
      if (token.startsWith('offline_')) {
        return false;
      }
      
      // Check JWT expiration
      return JwtDecoder.isExpired(token);
    } catch (e) {
      AppLogger.error('Failed to check token expiration', e);
      return true; // Assume expired on error
    }
  }
  
  @override
  Future<void> saveAuthTokenToDatabase(String userId, String userName, String token, {int? expiresAt}) async {
    await _dbHelper.saveAuthToken(userId, userName, token, expiresAt: expiresAt);
  }
  
  @override
  Future<Map<String, dynamic>?> getAuthTokenFromDatabase(String userName) async {
    return await _dbHelper.getLatestAuthToken(userName);
  }
  
  // Helper methods for password hashing
  
  String _generateSalt() {
    // Generate a random salt (in a real app, use a secure random generator)
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return base64Encode(utf8.encode(random));
  }
  
  String _hashPassword(String password, String salt) {
    // Combine password and salt, then hash
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}