import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../error/failures.dart';
import '../error/exceptions.dart';
import '../utils/logger.dart';
import '../utils/jwt_token_manager.dart';
import '../di/injection.dart';
import '../config/api_endpoints.dart';
import 'database_helper.dart';
import '../utils/jwt_decoder_util.dart';

class UserProfileRepository {
  final DatabaseHelper _dbHelper;
  final JwtTokenManager _tokenManager;
  final Dio _dio;
  final Connectivity _connectivity;

  UserProfileRepository({
    required DatabaseHelper dbHelper,
    required JwtTokenManager tokenManager,
    required Dio dio,
    required Connectivity connectivity,
  }) : _dbHelper = dbHelper,
       _tokenManager = tokenManager,
       _dio = dio,
       _connectivity = connectivity;

  /// Get user profile from JWT token and sync with local database
  Future<Either<Failure, Map<String, dynamic>>> getUserProfile({
    bool forceRefresh = false,
  }) async {
    try {
      // First try to get from JWT token
      final token = await _tokenManager.getAccessToken();
      if (token == null) {
        return Left(AuthFailure('No authentication token found'));
      }

      // Get user data from token
      final userInfo = JwtDecoderUtil.extractUserInfo(token);
      if (userInfo == null) {
        return Left(AuthFailure('Failed to extract user info from token'));
      }

      // Get user ID from token
      final userId = userInfo['Id'] ?? userInfo['sub'];
      if (userId == null) {
        return Left(AuthFailure('User ID not found in token'));
      }

      // Check if we need to sync with remote
      final shouldSync = await _shouldSyncWithRemote(userId, forceRefresh);

      if (shouldSync) {
        // Try to sync with remote server if we have connectivity
        final connectivityResult = await _connectivity.checkConnectivity();
        final hasConnectivity =
            connectivityResult.isNotEmpty &&
            !connectivityResult.contains(ConnectivityResult.none);

        // if (hasConnectivity) {
        //   try {
        //     // Fetch from remote API
        //     final remoteProfile = await _fetchRemoteProfile(token);

        //     // Save to local database
        //     await _saveUserToDatabase(remoteProfile);

        //     // Return remote data
        //     return Right(remoteProfile);
        //   } catch (e) {
        //     AppLogger.error('Failed to sync with remote server: $e');
        //     // Continue to use local data if available
        //   }
        // }
      }

      // Get from local database
      final localUser = await _getUserFromDatabase(userId);

      if (localUser != null) {
        return Right(localUser);
      }

      // If no local data, save token data to database
      await _saveUserToDatabase(userInfo);

      return Right(userInfo);
    } catch (e) {
      AppLogger.error('Failed to get user profile: $e');
      return Left(ServerFailure('Failed to get user profile: $e'));
    }
  }

  /// Update user profile data
  Future<Either<Failure, Map<String, dynamic>>> updateUserProfile(
    Map<String, dynamic> userData,
  ) async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasConnectivity =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      // Get user ID
      final userId = userData['Id'] ?? userData['sub'];
      if (userId == null) {
        return Left(ValidationFailure('User ID is required'));
      }

      // Add sync metadata
      final now = DateTime.now().millisecondsSinceEpoch;
      userData['local_updated_at'] = now;
      userData['is_dirty'] = 1;

      // Save to local database
      await _saveUserToDatabase(userData);

      // Add to sync queue
      await _addToSyncQueue(userId, userData);

      // Try to sync immediately if we have connectivity
      if (hasConnectivity) {
        try {
          final result = await syncUserProfile(userId);
          return result.fold((failure) {
            // Return updated local data even if sync failed
            return Right(userData);
          }, (syncedData) => Right(syncedData));
        } catch (e) {
          AppLogger.error('Failed to sync after update: $e');
          // Return local data even if sync failed
          return Right(userData);
        }
      }

      // Return updated local data
      return Right(userData);
    } catch (e) {
      AppLogger.error('Failed to update user profile: $e');
      return Left(ServerFailure('Failed to update user profile: $e'));
    }
  }

  /// Sync user profile with remote server
  Future<Either<Failure, Map<String, dynamic>>> syncUserProfile(
    String userId,
  ) async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasConnectivity =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (!hasConnectivity) {
        return Left(NetworkFailure('No internet connection available'));
      }

      // Get local user data
      final localUser = await _getUserFromDatabase(userId);
      if (localUser == null) {
        return Left(CacheFailure('No local user data found'));
      }

      // // Check if local data is dirty
      // final isDirty = localUser['is_dirty'] == 1;
      // if (!isDirty) {
      //   // If not dirty, just fetch latest from remote
      //   try {
      //     final token = await _tokenManager.getAccessToken();
      //     if (token == null) {
      //       return Left(AuthFailure('No authentication token found'));
      //     }

      //     final remoteProfile = await _fetchRemoteProfile(token);
      //     await _saveUserToDatabase(remoteProfile);
      //     return Right(remoteProfile);
      //   } catch (e) {
      //     AppLogger.error('Failed to fetch remote profile: $e');
      //     return Left(NetworkFailure('Failed to fetch remote profile: $e'));
      //   }
      // }

      // If dirty, push local changes to remote
      try {
        final result = await _pushLocalChangesToRemote(localUser);
        return Right(result);
      } catch (e) {
        AppLogger.error('Failed to push local changes: $e');

        // Update sync status
        await _dbHelper.update(
          'users',
          {'last_sync_status': 'failed', 'sync_error': e.toString()},
          where: 'id = ?',
          whereArgs: [userId],
        );

        return Left(NetworkFailure('Failed to push local changes: $e'));
      }
    } catch (e) {
      AppLogger.error('Failed to sync user profile: $e');
      return Left(ServerFailure('Failed to sync user profile: $e'));
    }
  }

  /// Process sync queue
  Future<Either<Failure, int>> processSyncQueue({int maxItems = 10}) async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasConnectivity =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (!hasConnectivity) {
        return Left(NetworkFailure('No internet connection available'));
      }

      // Get pending sync items
      final pendingItems = await _dbHelper.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'priority ASC, created_at ASC',
        limit: maxItems,
      );

      if (pendingItems.isEmpty) {
        return const Right(0); // No items to sync
      }

      int successCount = 0;

      // Process each item
      for (final item in pendingItems) {
        try {
          final operation = item['operation'] as String;
          final tableName = item['table_name'] as String;
          final data =
              jsonDecode(item['data'] as String) as Map<String, dynamic>;
          final itemId = item['id'] as int;

          if (tableName == 'users' && operation == 'update') {
            // Push changes to remote
            await _pushLocalChangesToRemote(data);
            // Mark as synced
            await _dbHelper.delete(
              'sync_queue',
              where: 'id = ?',
              whereArgs: [itemId],
            );
            successCount++;
          }
        } catch (e) {
          AppLogger.error('Failed to process sync item: $e');
          // Update retry count and error
          await _dbHelper.update(
            'sync_queue',
            {
              'retry_count': (item['retry_count'] as int) + 1,
              'last_error': e.toString(),
              'status':
                  (item['retry_count'] as int) >= 5 ? 'failed' : 'pending',
            },
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
      }

      return Right(successCount);
    } catch (e) {
      AppLogger.error('Failed to process sync queue: $e');
      return Left(ServerFailure('Failed to process sync queue: $e'));
    }
  }

  /// Check if we should sync with remote server
  Future<bool> _shouldSyncWithRemote(String userId, bool forceRefresh) async {
    if (forceRefresh) {
      return true;
    }

    try {
      // Get last sync time
      final results = await _dbHelper.query(
        'users',
        columns: ['synced_at'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (results.isEmpty) {
        return true; // No local data, should sync
      }

      final syncedAt = results.first['synced_at'] as int?;
      if (syncedAt == null) {
        return true; // Never synced, should sync
      }

      // Check if dirty
      final isDirty = results.first['is_dirty'] == 1;
      if (isDirty) {
        return true; // Local changes, should sync
      }

      // Check if sync is older than 1 hour
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final syncAge = now - syncedAt;
      final shouldSync = syncAge > 3600; // 1 hour in seconds

      return shouldSync;
    } catch (e) {
      AppLogger.error('Failed to check sync status: $e');
      return true; // Sync on error to be safe
    }
  }

  // /// Fetch user profile from remote API
  // Future<Map<String, dynamic>> _fetchRemoteProfile(String token) async {
  //   try {
  //     final response = await _dio.get(
  //       ApiEndpoints.profile,
  //       options: Options(headers: {'Authorization': 'Bearer $token'}),
  //     );

  //     if (response.statusCode == 200) {
  //       final data = response.data;

  //       // If the response is wrapped in a data field, extract it
  //       final userData =
  //           data is Map<String, dynamic> && data.containsKey('data')
  //               ? data['data'] as Map<String, dynamic>
  //               : data as Map<String, dynamic>;

  //       return userData;
  //     } else {
  //       throw ServerException(
  //         'Failed to fetch profile: ${response.statusCode}',
  //       );
  //     }
  //   } on DioException catch (e) {
  //     throw ServerException('Failed to fetch profile: ${e.message}');
  //   } catch (e) {
  //     // If we can't reach the server, fall back to token data
  //     final userInfo = JwtDecoderUtil.extractUserInfo(token);
  //     if (userInfo != null) {
  //       return userInfo;
  //     }
  //     throw ServerException('Failed to fetch profile: $e');
  //   }
  // }

  /// Push local changes to remote server
  Future<Map<String, dynamic>> _pushLocalChangesToRemote(
    Map<String, dynamic> userData,
  ) async {
    try {
      final token = await _tokenManager.getAccessToken();
      if (token == null) {
        throw AuthException('No authentication token found');
      }

      // Prepare data for API
      final apiData = Map<String, dynamic>.from(userData);
      // Remove local-only fields
      apiData.remove('is_dirty');
      apiData.remove('local_updated_at');
      apiData.remove('synced_at');
      apiData.remove('last_sync_status');
      apiData.remove('sync_error');

      // Send update to API - use the correct endpoint
      final response = await _dio.put(
        '${ApiEndpoints.baseUrl}/user/profile', // Use the correct endpoint path
        data: apiData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        // If the response is wrapped in a data field, extract it
        final updatedData =
            responseData is Map<String, dynamic> &&
                    responseData.containsKey('data')
                ? responseData['data'] as Map<String, dynamic>
                : responseData as Map<String, dynamic>;

        // Update local database with synced status
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        updatedData['synced_at'] = now;
        updatedData['is_dirty'] = 0;
        updatedData['last_sync_status'] = 'success';
        updatedData['sync_error'] = null;

        await _saveUserToDatabase(updatedData);

        return updatedData;
      } else {
        throw ServerException(
          'Failed to update profile: ${response.statusCode}',
        );
      }
    } catch (e) {
      AppLogger.error('Failed to push local changes: $e');
      throw ServerException('Failed to push local changes: $e');
    }
  }

  /// Get user from local database
  Future<Map<String, dynamic>?> _getUserFromDatabase(String userId) async {
    try {
      final results = await _dbHelper.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (results.isEmpty) {
        return null;
      }

      return results.first;
    } catch (e) {
      AppLogger.error('Failed to get user from database: $e');
      return null;
    }
  }

  /// Save user to local database
  Future<void> _saveUserToDatabase(Map<String, dynamic> userData) async {
    try {
      // Ensure required fields
      final userId = userData['Id'] ?? userData['sub'];
      if (userId == null) {
        throw ValidationException('User ID is required');
      }

      final username = userData['UserName'];
      if (username == null) {
        throw ValidationException('Username is required');
      }

      // Prepare data for database
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final dbData = {
        'id': userId,
        'UserName': username,
        'Nama': userData['Nama'],
        'synced_at': userData['synced_at'] ?? now,
        'last_sync_status': userData['last_sync_status'] ?? 'success',
        'sync_error': userData['sync_error'],
        'is_dirty': userData['is_dirty'] ?? 0,
        'local_updated_at': userData['local_updated_at'],
      };

      // Check if user exists
      final existingUser = await _getUserFromDatabase(userId);
      if (existingUser == null) {
        // Insert new user
        await _dbHelper.insert('users', dbData);
      } else {
        // Update existing user
        await _dbHelper.update(
          'users',
          dbData,
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
    } catch (e) {
      AppLogger.error('Failed to save user to database: $e');
      throw CacheException('Failed to save user to database: $e');
    }
  }

  /// Add user update to sync queue
  Future<void> _addToSyncQueue(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      // Check if there's already a pending sync for this user
      final existingItems = await _dbHelper.query(
        'sync_queue',
        where: 'table_name = ? AND record_id = ? AND status = ?',
        whereArgs: ['users', userId, 'pending'],
      );

      if (existingItems.isNotEmpty) {
        // Update existing sync item
        await _dbHelper.update(
          'sync_queue',
          {
            'data': jsonEncode(userData),
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'retry_count': 0,
            'last_error': null,
          },
          where: 'id = ?',
          whereArgs: [existingItems.first['id']],
        );
      } else {
        // Add new sync item
        await _dbHelper.insert('sync_queue', {
          'operation': 'update',
          'table_name': 'users',
          'record_id': userId,
          'data': jsonEncode(userData),
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'priority': 1, // High priority for user data
          'status': 'pending',
        });
      }
    } catch (e) {
      AppLogger.error('Failed to add to sync queue: $e');
      throw CacheException('Failed to add to sync queue: $e');
    }
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return await _tokenManager.getAccessToken();
  }
}
