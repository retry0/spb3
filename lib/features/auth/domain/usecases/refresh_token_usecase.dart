import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/auth/token_manager.dart';
import '../../../../core/di/injection.dart';
import '../entities/auth_tokens.dart';
import '../repositories/auth_repository.dart';

/// Use case for refreshing authentication tokens
class RefreshTokenUseCase {
  final AuthRepository repository;
  final TokenManager _tokenManager;

  RefreshTokenUseCase(this.repository)
      : _tokenManager = getIt<TokenManager>();

  /// Refreshes the authentication token if needed
  /// Returns a new token if successful, or a failure if the token cannot be refreshed
  Future<Either<Failure, AuthTokens>> call() async {
    try {
      // First validate the current token
      final validationResult = await repository.validateToken();
      
      return await validationResult.fold(
        (failure) async {
          // Token is invalid, try to refresh it
          return await repository.refreshToken();
        },
        (isValid) async {
          if (isValid) {
            // Token is still valid, but we'll refresh it anyway
            // This is useful for extending the session
            return await repository.refreshToken();
          } else {
            // Token is invalid, try to refresh it
            return await repository.refreshToken();
          }
        },
      );
    } catch (e) {
      return Left(AuthFailure('Failed to refresh authentication token: $e'));
    }
  }
  
  /// Validates the current token
  /// Returns true if the token is valid, false otherwise
  Future<Either<Failure, bool>> validateToken() async {
    try {
      return await repository.validateToken();
    } catch (e) {
      return Left(AuthFailure('Failed to validate authentication token: $e'));
    }
  }
  
  /// Manually force a token refresh
  Future<Either<Failure, AuthTokens>> forceRefresh() async {
    try {
      // Force token refresh through the token manager
      final newToken = await _tokenManager.refreshToken();
      
      if (newToken != null) {
        // Create a new AuthTokens object with the refreshed token
        return Right(AuthTokens(token: newToken));
      } else {
        return Left(AuthFailure('Failed to refresh token'));
      }
    } catch (e) {
      return Left(AuthFailure('Failed to force token refresh: $e'));
    }
  }
  
  /// Handle offline to online transition
  Future<Either<Failure, bool>> handleReconnection() async {
    try {
      final isValid = await _tokenManager.validateTokenOnReconnect();
      return Right(isValid);
    } catch (e) {
      return Left(AuthFailure('Failed to validate token after reconnection: $e'));
    }
  }
}