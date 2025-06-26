import 'package:dartz/dartz.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/repositories/spb_repository.dart';
import '../datasources/spb_remote_datasource.dart';
import '../datasources/spb_local_datasource.dart';
import '../models/spb_model.dart';

class SpbRepositoryImpl implements SpbRepository {
  final SpbRemoteDataSource remoteDataSource;
  final SpbLocalDataSource localDataSource;
  final Connectivity connectivity;

  SpbRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.connectivity,
  });

  @override
  Future<Either<Failure, List<SpbModel>>> getSpbForDriver({
    required String driver,
    required String kdVendor,
    bool forceRefresh = false,
  }) async {
    // Check if we have connectivity
    final connectivityResult = await connectivity.checkConnectivity();
    final hasConnectivity =
        connectivityResult.isNotEmpty &&
        !connectivityResult.contains(ConnectivityResult.none);

    if (hasConnectivity && forceRefresh) {
      try {
        // Fetch from remote
        final remoteSpbList = await remoteDataSource.getSpbForDriver(
          driver: driver,
          kdVendor: kdVendor,
        );

        // Save to local storage
        await localDataSource.saveSpbList(
          remoteSpbList,
          driver: driver,
          kdVendor: kdVendor,
        );

        return Right(remoteSpbList);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on NetworkException catch (e) {
        // If network fails, try to get from local storage
        return _getFromLocalStorage(driver, kdVendor);
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    } else {
      // Try to get from local storage first
      final localResult = await _getFromLocalStorage(driver, kdVendor);

      // If we have connectivity and no local data or need to sync, try remote
      if (hasConnectivity && (localResult.isLeft() || _needsSync())) {
        try {
          final remoteSpbList = await remoteDataSource.getSpbForDriver(
            driver: driver,
            kdVendor: kdVendor,
          );

          // Save to local storage
          await localDataSource.saveSpbList(
            remoteSpbList,
            driver: driver,
            kdVendor: kdVendor,
          );

          return Right(remoteSpbList);
        } catch (e) {
          // If remote fails but we have local data, return that
          if (localResult.isRight()) {
            return localResult;
          }
          // Otherwise return the error
          if (e is ServerException) {
            return Left(ServerFailure(e.message));
          } else if (e is NetworkException) {
            return Left(NetworkFailure(e.message));
          } else {
            return Left(ServerFailure(e.toString()));
          }
        }
      }

      return localResult;
    }
  }

  Future<Either<Failure, List<SpbModel>>> _getFromLocalStorage(
    String driver,
    String kdVendor,
  ) async {
    try {
      final localSpbList = await localDataSource.getSpbForDriver(
        driver: driver,
        kdVendor: kdVendor,
      );

      if (localSpbList.isEmpty) {
        return Left(CacheFailure('No SPB data found in local storage'));
      }

      return Right(localSpbList);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  bool _needsSync() {
    // In a real app, you might check when the data was last synced
    // For now, we'll just return true to always try to sync when online
    return true;
  }

  @override
  Future<Either<Failure, void>> syncSpbData({
    required String driver,
    required String kdVendor,
  }) async {
    try {
      // Check connectivity
      final connectivityResult = await connectivity.checkConnectivity();
      final hasConnectivity =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (!hasConnectivity) {
        return Left(NetworkFailure('No internet connection available'));
      }

      // Get unsynced data
      final unsyncedSpbList = await localDataSource.getUnsyncedSpb();

      // If there's unsynced data, we would push it to the server here
      // For this implementation, we'll just mark them as synced
      for (final spb in unsyncedSpbList) {
        await localDataSource.markAsSynced(spb.noSpb);
      }

      // Fetch latest data from server
      final remoteSpbList = await remoteDataSource.getSpbForDriver(
        driver: driver,
        kdVendor: kdVendor,
      );

      // Save to local storage
      await localDataSource.saveSpbList(
        remoteSpbList,
        driver: driver,
        kdVendor: kdVendor,
      );

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearAllSpbData() async {
    try {
      await localDataSource.clearAllSpb();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}