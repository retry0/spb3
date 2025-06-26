import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/username_validator.dart';
import '../entities/auth_tokens.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Either<Failure, AuthTokens>> call(
    String userName,
    String password,
  ) async {
    // Validate userName format
    final userNameError = UserNameValidator.validateFormat(userName);
    if (userNameError != null) {
      return Left(ValidationFailure(userNameError));
    }

    // Validate password
    if (password.isEmpty) {
      return Left(ValidationFailure('Password is required'));
    }

    // Normalize userName
    final normalizedUserName = UserNameValidator.normalize(userName);

    // Attempt login
    return await repository.loginWithUserName(normalizedUserName, password);
  }
}
