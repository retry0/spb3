import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/user_profile_repository.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final AuthRepository authRepository;
  final ProfileRemoteDataSource remoteDataSource;
  final UserProfileRepository userProfileRepository;

  ProfileRepositoryImpl({
    required this.authRepository,
    required this.remoteDataSource,
    required this.userProfileRepository,
  });

  @override
  Future<Either<Failure, User>> getUserProfile() async {
    try {
      // First try to get user from auth repository
      final authResult = await authRepository.getCurrentUser();

      return authResult.fold((failure) async {
        // If auth repository fails, try user profile repository
        final result = await userProfileRepository.getUserProfile();
        return result.fold((failure) => Left(failure), (userData) {
          // Convert to User entity
          final user = User(
            Id: userData['Id'] ?? userData['sub'] ?? '',
            UserName: userData['UserName'] ?? '',
            Nama: userData['Nama'] ?? '',
          );
          return Right(user);
        });
      }, (user) => Right(user));
    } catch (e) {
      return Left(ServerFailure('Failed to get user profile: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String userName,
    required String oldPassword,
    required String newPassword,
    required String requestor,
  }) async {
    try {
      await remoteDataSource.changePassword({
        'userName': userName,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'requestor': requestor,
      });

      // After successful password change, logout to clear all sessions
      await authRepository.logout();

      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> updateUserProfile(User user) async {
    try {
      // Convert User entity to Map
      final userData = {
        'Id': user.Id,
        'UserName': user.UserName,
        'Nama': user.Nama,
      };

      // Update user profile
      final result = await userProfileRepository.updateUserProfile(userData);

      return result.fold((failure) => Left(failure), (updatedData) {
        // Convert back to User entity
        final updatedUser = User(
          Id: updatedData['Id'] ?? updatedData['sub'] ?? '',
          UserName: updatedData['UserName'] ?? '',
          Nama: updatedData['Nama'] ?? '',
        );

        return Right(updatedUser);
      });
    } catch (e) {
      return Left(ServerFailure('Failed to update user profile: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> syncUserProfile() async {
    try {
      // Get user ID from current user
      final userResult = await getUserProfile();

      return await userResult.fold((failure) => Left(failure), (user) async {
        // Sync user profile
        final result = await userProfileRepository.syncUserProfile(user.Id);

        return result.fold(
          (failure) => Left(failure),
          (syncedData) => const Right(true),
        );
      });
    } catch (e) {
      return Left(ServerFailure('Failed to sync user profile: $e'));
    }
  }
}
