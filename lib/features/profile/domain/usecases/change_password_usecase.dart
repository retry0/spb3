import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/repositories/profile_repository.dart';

class ChangePasswordUseCase {
  final ProfileRepository repository;

  ChangePasswordUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String userName,
    required String oldPassword,
    required String newPassword,
    required String requestor,
  }) async {
    // Validate inputs
    if (userName.isEmpty) {
      return Left(ValidationFailure('Username is required'));
    }

    if (oldPassword.isEmpty) {
      return Left(ValidationFailure('Current password is required'));
    }

    if (newPassword.isEmpty) {
      return Left(ValidationFailure('New password is required'));
    }

    // if (newPassword.length < 8) {
    //   return Left(ValidationFailure('New password must be at least 8 characters long'));
    // }

    // Call repository
    return await repository.changePassword(
      userName: userName,
      oldPassword: oldPassword,
      newPassword: newPassword,
      requestor: requestor,
    );
  }
}
