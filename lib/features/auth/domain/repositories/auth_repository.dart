import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../entities/auth_tokens.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthTokens>> loginWithUserName(
    String userName,
    String password,
  );
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, User>> getCurrentUser();
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
  );
  Future<bool> isLoggedIn();
  
  // Token management
  Future<Either<Failure, bool>> validateToken();
  Future<Either<Failure, AuthTokens>> refreshToken();
}