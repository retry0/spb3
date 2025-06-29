import 'package:dartz/dartz.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/espb_repository.dart';
import '../datasources/espb_local_datasource.dart';
import '../datasources/espb_remote_datasource.dart';
import '../models/espb_form_model.dart';

class EspbRepositoryImpl implements EspbRepository {
  final EspbLocalDataSource localDataSource;
  final EspbRemoteDataSource remoteDataSource;
  final Connectivity connectivity;

  EspbRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.connectivity,
  });

  @override
  Future<Either<Failure, bool>> saveEspbForm(EspbFormModel formData) async {
    try {
      // Always save to local storage first
      final saveResult = await localDataSource.saveEspbFormData(formData);
      
      if (!saveResult) {
        return Left(CacheFailure('Failed to save ESPB form data locally'));
      }
      
      // Check if we have connectivity
      final connectivityResult = await connectivity.checkConnectivity();
      final hasConnectivity = connectivityResult.isNotEmpty && 
                             !connectivityResult.contains(ConnectivityResult.none);
      
      if (hasConnectivity) {
        try {
          // Try to sync immediately if online
          final syncResult = await remoteDataSource.submitEspbForm(formData);
          
          if (syncResult) {
            // Mark as synced in local storage
            await localDataSource.markEspbFormAsSynced(formData.noSpb);
            return const Right(true);
          } else {
            // Sync failed but data is saved locally
            return const Right(false);
          }
        } on TimeoutException catch (e) {
          AppLogger.warning('Timeout syncing ESPB form: ${e.message}');
          return const Right(false); // Data is saved locally
        } on NetworkException catch (e) {
          AppLogger.warning('Network error syncing ESPB form: ${e.message}');
          return const Right(false); // Data is saved locally
        } on ServerException catch (e) {
          AppLogger.warning('Server error syncing ESPB form: ${e.message}');
          
          // Update sync status with error
          await localDataSource.updateEspbFormSyncStatus(
            formData.noSpb,
            errorMessage: e.message,
          );
          
          return const Right(false); // Data is saved locally
        }
      }
      
      // Offline - data saved locally only
      return const Right(false);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, EspbFormModel?>> getEspbForm(String noSpb) async {
    try {
      final formData = await localDataSource.getEspbFormData(noSpb);
      return Right(formData);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to get ESPB form: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> syncEspbForm(String noSpb) async {
    try {
      // Check connectivity
      final connectivityResult = await connectivity.checkConnectivity();
      final hasConnectivity = connectivityResult.isNotEmpty && 
                             !connectivityResult.contains(ConnectivityResult.none);
      
      if (!hasConnectivity) {
        return Left(NetworkFailure('No internet connection available'));
      }
      
      // Get form data from local storage
      final formData = await localDataSource.getEspbFormData(noSpb);
      
      if (formData == null) {
        return Left(CacheFailure('ESPB form not found in local storage'));
      }
      
      // Check if already synced
      if (formData.isSynced) {
        return const Right(true);
      }
      
      // Try to sync with server
      final syncResult = await remoteDataSource.submitEspbForm(formData);
      
      if (syncResult) {
        // Mark as synced in local storage
        await localDataSource.markEspbFormAsSynced(noSpb);
        return const Right(true);
      } else {
        // Update retry count
        await localDataSource.updateEspbFormSyncStatus(
          noSpb,
          retryCount: formData.retryCount + 1,
        );
        
        return const Right(false);
      }
    } on TimeoutException catch (e) {
      return Left(TimeoutFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> syncAllPendingEspbForms() async {
    try {
      // Check connectivity
      final connectivityResult = await connectivity.checkConnectivity();
      final hasConnectivity = connectivityResult.isNotEmpty && 
                             !connectivityResult.contains(ConnectivityResult.none);
      
      if (!hasConnectivity) {
        return Left(NetworkFailure('No internet connection available'));
      }
      
      // Get all pending forms
      final pendingForms = await localDataSource.getPendingEspbForms();
      
      if (pendingForms.isEmpty) {
        return const Right(0); // No forms to sync
      }
      
      int successCount = 0;
      
      // Try to sync each form
      for (final form in pendingForms) {
        try {
          final syncResult = await remoteDataSource.submitEspbForm(form);
          
          if (syncResult) {
            // Mark as synced
            await localDataSource.markEspbFormAsSynced(form.noSpb);
            successCount++;
          } else {
            // Update retry count
            await localDataSource.updateEspbFormSyncStatus(
              form.noSpb,
              retryCount: form.retryCount + 1,
            );
          }
        } catch (e) {
          AppLogger.error('Error syncing form ${form.noSpb}: $e');
          
          // Update error message
          await localDataSource.updateEspbFormSyncStatus(
            form.noSpb,
            errorMessage: e.toString(),
            retryCount: form.retryCount + 1,
          );
        }
      }
      
      return Right(successCount);
    } catch (e) {
      return Left(ServerFailure('Failed to sync pending ESPB forms: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> migrateEspbFormsFromSharedPreferences() async {
    try {
      await localDataSource.migrateFromSharedPreferences();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to migrate ESPB forms: $e'));
    }
  }
}