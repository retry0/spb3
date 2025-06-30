import 'package:dartz/dartz.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';

import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/jwt_decoder_util.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/jwt_token_manager.dart';
import '../../../../core/auth/token_manager.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';
import '../models/user_model.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/storage/secure_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final Connectivity connectivity;
  final TokenManager _tokenManager;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.connectivity,
  }) : _tokenManager = getIt<TokenManager>();

  @override
  Future<Either<Failure, AuthTokens>> loginWithUserName(
    String userName,
    String password,
  ) async {
    try {
      // Check connectivity first
      final connectivityResult = await connectivity.checkConnectivity();
      final hasConnectivity =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (hasConnectivity) {
        // Try online authentication first
        try {
          final tokens = await remoteDataSource.loginWithUserName({
            'userName': userName,
            'password': password,
          });

          // Save token to secure storage and database
          await localDataSource.saveToken(tokens.token);

          // Save credentials for offline authentication
          await localDataSource.saveOfflineCredentials(userName, password);

          // Update last online authentication timestamp
          await localDataSource.updateLastOnlineAuth(userName);
          AppLogger.warning('AUTH OFFLINE: ${userName}');
          return Right(tokens);
        } on NetworkException catch (e) {
          // Network error - try offline authentication
          AppLogger.warning(
            'Network error during login, trying offline authentication: ${e.message}',
          );
          return await _tryOfflineAuthentication(userName, password);
        } on ServerException catch (e) {
          // Server error - try offline authentication
          AppLogger.warning(
            'Server error during login, trying offline authentication: ${e.message}',
          );
          return await _tryOfflineAuthentication(userName, password);
        } on AuthException catch (e) {
          // Auth error - don't try offline authentication for security reasons
          return Left(
            AuthFailure(
              e.message,
              endpoint: e.endpoint ?? '/Account/LoginUser',
              statusCode: e.statusCode,
              errorCode: e.errorCode,
              details: e.details,
            ),
          );
        }
      } else {
        // No connectivity - try offline authentication
        AppLogger.info('No internet connection, trying offline authentication');
        return await _tryOfflineAuthentication(userName, password);
      }
    } catch (e) {
      // For unexpected errors, create a more descriptive message
      final errorMessage = e.toString();
      return Left(
        ServerFailure(
          errorMessage.isNotEmpty
              ? 'Login failed: $errorMessage'
              : 'An unexpected error occurred during login',
          endpoint: '/Account/LoginUser',
        ),
      );
    }
  }

  Future<Either<Failure, AuthTokens>> _tryOfflineAuthentication(
    String userName,
    String password,
  ) async {
    try {
      // Verify stored credentials
      final isValid = await localDataSource.verifyOfflineCredentials(
        userName,
        password,
      );

      if (!isValid) {
        return Left(
          AuthFailure('Invalid credentials for offline authentication'),
        );
      }

      // Get user from local database
      final user = await localDataSource.getUser(userName);

      if (user == null) {
        return Left(AuthFailure('User not found in local database'));
      }

      // Create an offline token (not a real JWT, just a marker)
      final offlineToken = 'offline_${DateTime.now().millisecondsSinceEpoch}';

      // Save the offline token
      await localDataSource.saveToken(offlineToken);

      // Return success with the offline token
      return Right(AuthTokens(token: offlineToken));
    } catch (e) {
      AppLogger.error('Offline authentication failed: $e');
      return Left(AuthFailure('Offline authentication failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      // Clear local token storage
      await localDataSource.clearToken();

      // Clear JWT token manager data
      final tokenManager = getIt<JwtTokenManager>();
      await tokenManager.clearStoredToken();

      // Clear any other sensitive data
      await _clearAllSensitiveData();

      return const Right(null);
    } on AuthException catch (e) {
      // Even if there's an error, try to clear local data
      try {
        await localDataSource.clearToken();
        final tokenManager = getIt<JwtTokenManager>();
        await tokenManager.clearStoredToken();
        await _clearAllSensitiveData();
      } catch (clearError) {
        print('Error during cleanup after logout failure: $clearError');
      }

      return Left(
        AuthFailure(
          e.message,
          endpoint: e.endpoint ?? '/auth/logout',
          statusCode: e.statusCode,
          errorCode: e.errorCode,
          details: e.details,
        ),
      );
    } catch (e) {
      // Even if there's an error, try to clear local data
      try {
        await localDataSource.clearToken();
        final tokenManager = getIt<JwtTokenManager>();
        await tokenManager.clearStoredToken();
        await _clearAllSensitiveData();
      } catch (clearError) {
        print('Error during cleanup after logout failure: $clearError');
      }

      // Still return success since we've cleared local data
      return const Right(null);
    }
  }

  // Helper method to clear all sensitive data
  Future<void> _clearAllSensitiveData() async {
    try {
      // Clear any additional sensitive data here
      // This could include cached user data, preferences, etc.
      await _tokenManager.clearTokens();
    } catch (e) {
      print('Error clearing sensitive data: $e');
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      // Get user data from JWT token
      final tokenManager = getIt<JwtTokenManager>();
      final userData = await tokenManager.getCurrentUserData();

      if (userData != null) {
        // Create User entity from JWT data
        final user = User(
          Id: userData['Id'] ?? userData['sub'] ?? '',
          UserName: userData['UserName'] ?? '',
          Nama: userData['Nama'] ?? '',
        );

        return Right(user);
      }

      // If no valid token or user data, try to get from local database
      final token = await localDataSource.getAccessToken();
      if (token != null) {
        // Check if it's an offline token
        if (token.startsWith('offline_')) {
          // For offline tokens, extract username from secure storage
          final userInfoJson = await getIt<SecureStorage>().read('user_info');
          if (userInfoJson != null) {
            final userInfo = jsonDecode(userInfoJson) as Map<String, dynamic>;
            final userName = userInfo['UserName'];

            if (userName != null) {
              final localUser = await localDataSource.getUser(userName);
              if (localUser != null) {
                return Right(localUser);
              }
            }
          }
          return Left(
            AuthFailure('No valid user data found for offline token'),
          );
        }

        // Try to extract user ID from token
        final decodedToken = JwtDecoderUtil.decodeAndFilterToken(token);
        if (decodedToken != null) {
          final userId = decodedToken['Id'] ?? decodedToken['sub'];
          if (userId != null) {
            final localUser = await localDataSource.getUserById(
              userId.toString(),
            );
            if (localUser != null) {
              return Right(localUser);
            }
          }
        }
      }

      // No need to make a remote API call - we should have the data from the token
      return Left(
        AuthFailure('No valid user data found', endpoint: '/user/profile'),
      );
    } on AuthException catch (e) {
      return Left(
        AuthFailure(
          e.message,
          endpoint: e.endpoint ?? '/user/profile',
          statusCode: e.statusCode,
          errorCode: e.errorCode,
          details: e.details,
        ),
      );
    } on NetworkException catch (e) {
      return Left(
        NetworkFailure(
          e.message,
          endpoint: e.endpoint ?? '/user/profile',
          statusCode: e.statusCode,
          errorCode: e.errorCode,
          details: e.details,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure('Failed to get user data', endpoint: '/user/profile'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      // Check connectivity first
      final connectivityResult = await connectivity.checkConnectivity();
      final hasConnectivity =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (!hasConnectivity) {
        return Left(
          NetworkFailure(
            'No internet connection available. Password changes require an active internet connection.',
          ),
        );
      }

      await remoteDataSource.changePassword({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      // After successful password change, update offline credentials
      try {
        // Get current user
        final tokenManager = getIt<JwtTokenManager>();
        final userData = await tokenManager.getCurrentUserData();

        if (userData != null && userData['UserName'] != null) {
          await localDataSource.saveOfflineCredentials(
            userData['UserName'],
            newPassword,
          );
        }
      } catch (e) {
        // Log but don't fail if offline credentials update fails
        AppLogger.warning(
          'Failed to update offline credentials after password change: $e',
        );
      }

      return const Right(null);
    } on AuthException catch (e) {
      return Left(
        AuthFailure(
          e.message,
          endpoint: e.endpoint ?? '/Account/api/ChangePassword',
          statusCode: e.statusCode,
          errorCode: e.errorCode,
          details: e.details,
        ),
      );
    } on ValidationException catch (e) {
      return Left(
        ValidationFailure(
          e.message,
          endpoint: e.endpoint ?? '/Account/api/ChangePassword',
          statusCode: e.statusCode,
          errorCode: e.errorCode,
          details: e.details,
        ),
      );
    } on NetworkException catch (e) {
      return Left(
        NetworkFailure(
          e.message,
          endpoint: e.endpoint ?? '/Account/api/ChangePassword',
          statusCode: e.statusCode,
          errorCode: e.errorCode,
          details: e.details,
        ),
      );
    } on TimeoutException catch (e) {
      return Left(
        TimeoutFailure(
          e.message,
          endpoint: e.endpoint ?? '/Account/api/ChangePassword',
          statusCode: e.statusCode,
          errorCode: e.errorCode,
          details: e.details,
        ),
      );
    } on OfflineException catch (e) {
      return Left(
        OfflineFailure(
          e.message,
          endpoint: e.endpoint ?? '/Account/api/ChangePassword',
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(
          'Failed to change password',
          endpoint: '/Account/api/ChangePassword',
        ),
      );
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final token = await localDataSource.getAccessToken();

      if (token == null) return false;

      // Check if it's an offline token
      if (token.startsWith('offline_')) {
        // Offline tokens are considered valid
        return true;
      }

      // Check if regular JWT token is expired
      return !JwtDecoder.isExpired(token);
    } catch (e) {
      return false;
    }
  }

  /// Gets user permissions from JWT token
  Future<List<String>> getUserPermissions() async {
    try {
      final tokenManager = getIt<JwtTokenManager>();
      final claims = await tokenManager.getSpecificClaims([
        'permissions',
        'roles',
        'scope',
      ]);

      final List<String> permissions = [];

      // Extract permissions from various claim formats
      if (claims['permissions'] is List) {
        permissions.addAll((claims['permissions'] as List).cast<String>());
      }

      if (claims['roles'] is List) {
        permissions.addAll((claims['roles'] as List).cast<String>());
      }

      if (claims['scope'] is String) {
        permissions.addAll((claims['scope'] as String).split(' '));
      }

      return permissions.toSet().toList(); // Remove duplicates
    } catch (e) {
      return [];
    }
  }

  /// Gets custom user attributes from JWT token
  Future<Map<String, dynamic>> getUserAttributes() async {
    try {
      final tokenManager = getIt<JwtTokenManager>();
      return await tokenManager.getCustomClaims() ?? {};
    } catch (e) {
      return {};
    }
  }

  @override
  Future<Either<Failure, AuthTokens>> refreshToken() async {
    try {
      // Use the token manager to refresh the token
      final newToken = await _tokenManager.refreshToken();
      
      if (newToken != null) {
        return Right(AuthTokens(token: newToken));
      } else {
        return Left(AuthFailure('Failed to refresh token'));
      }
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on RateLimitException catch (e) {
      return Left(RateLimitFailure(
        e.message,
        retryAfterSeconds: e.retryAfterSeconds,
      ));
    } catch (e) {
      return Left(ServerFailure('Unexpected error during token refresh: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> validateToken() async {
    try {
      // Check if we have a token
      final token = await localDataSource.getAccessToken();
      if (token == null) {
        return const Right(false);
      }
      
      // For offline tokens, consider them valid
      if (token.startsWith('offline_')) {
        return const Right(true);
      }
      
      // For regular tokens, check expiration
      if (JwtDecoder.isExpired(token)) {
        // Token is expired, try to refresh
        final refreshResult = await refreshToken();
        return refreshResult.fold(
          (failure) => const Right(false),
          (tokens) => const Right(true),
        );
      }
      
      // Token is valid
      return const Right(true);
    } catch (e) {
      return Left(AuthFailure('Failed to validate token: $e'));
    }
  }
}