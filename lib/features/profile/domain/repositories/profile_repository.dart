import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/user.dart';

abstract class ProfileRepository {
  Future<Either<Failure, User>> getUserProfile();

  Future<Either<Failure, void>> changePassword({
    required String userName,
    required String oldPassword,
    required String newPassword,
    required String requestor,
  });

  Future<Either<Failure, User>> updateUserProfile(User user);

  Future<Either<Failure, bool>> syncUserProfile();
}
