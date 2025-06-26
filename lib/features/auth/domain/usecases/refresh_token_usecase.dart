import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/auth_tokens.dart';
import '../repositories/auth_repository.dart';

/// Use case for refreshing authentication tokens
class RefreshTokenUseCase {
  final AuthRepository repository;

  RefreshTokenUseCase(this.repository);

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
            // Token is still valid, get it
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
}