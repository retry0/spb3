import 'package:dartz/dartz.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../datasources/espb_form_local_datasource.dart';
import '../datasources/espb_form_remote_datasource.dart';
import '../models/espb_form_data.dart';
import '../../domain/repositories/espb_form_repository.dart';

class EspbFormRepositoryImpl implements EspbFormRepository {
  final EspbFormLocalDataSource _localDataSource;
  final EspbFormRemoteDataSource _remoteDataSource;
  final Connectivity _connectivity;
  
  // Maximum number of retry attempts
  static const int _maxRetryAttempts = 5;
  
  EspbFormRepositoryImpl({
    required EspbFormLocalDataSource localDataSource,
    required EspbFormRemoteDataSource remoteDataSource,
    required Connectivity connectivity,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _connectivity = connectivity;
  
  @override
  Future<Either<Failure, bool>> saveEspbFormData(EspbFormData formData) async {
    try {
      // Validate required fields
      if (!_validateFormData(formData)) {
        return Left(ValidationFailure('Missing required fields in ESPB form data'));
      }
      
      // Save to local database
      await _localDataSource.saveEspbFormData(formData);
      
      // Check if we have connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasConnectivity = connectivityResult.isNotEmpty && 
                             !connectivityResult.contains(ConnectivityResult.none);
      
      // If online, attempt to sync immediately
      if (hasConnectivity) {
        try {
          final syncResult = await syncEspbFormData(formData.noSpb);
          return syncResult.fold(
            (failure) {
              // Still return success since we saved locally
              AppLogger.warning('Failed to sync ESPB form data: ${failure.message}');
              return const Right(true);
            },
            (success) => const Right(true),
          );
        } catch (e) {
          // Still return success since we saved locally
          AppLogger.warning('Error during immediate sync: $e');
          return const Right(true);
        }
      }
      
      return const Right(true);
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to save ESPB form data: $e'));
    }
  }
  
  @override
  Future<Either<Failure, List<EspbFormData>>> getAllEspbFormData() async {
    try {
      final formDataList = await _localDataSource.getAllEspbFormData();
      return Right(formDataList);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to get all ESPB form data: $e'));
    }
  }
  
  @override
  Future<Either<Failure, List<EspbFormData>>> getUnsyncedEspbFormData() async {
    try {
      final unsyncedData = await _localDataSource.getUnsyncedEspbFormData();
      return Right(unsyncedData);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to get unsynced ESPB form data: $e'));
    }
  }
  
  @override
  Future<Either<Failure, int>> syncUnsyncedEspbFormData() async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasConnectivity = connectivityResult.isNotEmpty && 
                             !connectivityResult.contains(ConnectivityResult.none);
      
      if (!hasConnectivity) {
        return Left(NetworkFailure('No internet connection available'));
      }
      
      // Get all unsynced data
      final unsyncedData = await _localDataSource.getUnsyncedEspbFormData();
      
      if (unsyncedData.isEmpty) {
        return const Right(0); // No data to sync
      }
      
      int successCount = 0;
      
      // Process each unsynced item
      for (final formData in unsyncedData) {
        try {
          // Skip items that have exceeded max retry attempts
          if (formData.retryCount >= _maxRetryAttempts) {
            AppLogger.warning('Skipping sync for SPB ${formData.noSpb}: max retry attempts exceeded');
            continue;
          }
          
          // Check if this SPB has already been processed on the server
          final isAlreadyProcessed = await _remoteDataSource.checkSpbProcessStatus(formData.noSpb);
          
          if (isAlreadyProcessed) {
            // If already processed, mark as synced locally
            await _localDataSource.markAsSynced(formData.noSpb);
            successCount++;
            AppLogger.info('SPB ${formData.noSpb} already processed on server, marked as synced locally');
            continue;
          }
          
          // Submit to API
          final success = await _remoteDataSource.submitEspbFormData(formData);
          
          if (success) {
            // Mark as synced
            await _localDataSource.markAsSynced(formData.noSpb);
            successCount++;
            AppLogger.info('Successfully synced ESPB form data for SPB: ${formData.noSpb}');
          } else {
            // Update retry count
            await _localDataSource.incrementRetryCount(formData.noSpb);
            await _localDataSource.updateSyncStatus(
              formData.noSpb, 
              false, 
              'Failed to sync with server'
            );
            AppLogger.warning('Failed to sync ESPB form data for SPB: ${formData.noSpb}');
          }
        } on NetworkException catch (e) {
          // Network error - update retry count and error message
          await _localDataSource.incrementRetryCount(formData.noSpb);
          await _localDataSource.updateSyncStatus(formData.noSpb, false, e.message);
          AppLogger.warning('Network error syncing SPB ${formData.noSpb}: ${e.message}');
        } on ServerException catch (e) {
          // Server error - update retry count and error message
          await _localDataSource.incrementRetryCount(formData.noSpb);
          await _localDataSource.updateSyncStatus(formData.noSpb, false, e.message);
          AppLogger.warning('Server error syncing SPB ${formData.noSpb}: ${e.message}');
        } catch (e) {
          // Unexpected error - update retry count and error message
          await _localDataSource.incrementRetryCount(formData.noSpb);
          await _localDataSource.updateSyncStatus(formData.noSpb, false, e.toString());
          AppLogger.error('Unexpected error syncing SPB ${formData.noSpb}: $e');
        }
      }
      
      return Right(successCount);
    } catch (e) {
      AppLogger.error('Failed to sync unsynced ESPB form data: $e');
      return Left(ServerFailure('Failed to sync unsynced ESPB form data: $e'));
    }
  }
  
  @override
  Future<Either<Failure, bool>> syncEspbFormData(String spbNumber) async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasConnectivity = connectivityResult.isNotEmpty && 
                             !connectivityResult.contains(ConnectivityResult.none);
      
      if (!hasConnectivity) {
        return Left(NetworkFailure('No internet connection available'));
      }
      
      // Get the form data
      final formData = await _localDataSource.getEspbFormDataBySpbNumber(spbNumber);
      
      if (formData == null) {
        return Left(CacheFailure('ESPB form data not found for SPB: $spbNumber'));
      }
      
      // Skip if already synced
      if (formData.isSynced) {
        return const Right(true);
      }
      
      // Check if this SPB has already been processed on the server
      final isAlreadyProcessed = await _remoteDataSource.checkSpbProcessStatus(spbNumber);
      
      if (isAlreadyProcessed) {
        // If already processed, mark as synced locally
        await _localDataSource.markAsSynced(spbNumber);
        AppLogger.info('SPB $spbNumber already processed on server, marked as synced locally');
        return const Right(true);
      }
      
      // Submit to API
      final success = await _remoteDataSource.submitEspbFormData(formData);
      
      if (success) {
        // Mark as synced
        await _localDataSource.markAsSynced(spbNumber);
        AppLogger.info('Successfully synced ESPB form data for SPB: $spbNumber');
        return const Right(true);
      } else {
        // Update retry count and error message
        await _localDataSource.incrementRetryCount(spbNumber);
        await _localDataSource.updateSyncStatus(
          spbNumber, 
          false, 
          'Failed to sync with server'
        );
        AppLogger.warning('Failed to sync ESPB form data for SPB: $spbNumber');
        return Left(ServerFailure('Failed to sync ESPB form data with server'));
      }
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to sync ESPB form data: $e'));
    }
  }
  
  @override
  Future<bool> hasUnsyncedData() async {
    try {
      final unsyncedData = await _localDataSource.getUnsyncedEspbFormData();
      return unsyncedData.isNotEmpty;
    } catch (e) {
      AppLogger.error('Error checking for unsynced data: $e');
      return false;
    }
  }
  
  @override
  Future<Either<Failure, bool>> getSyncStatus(String spbNumber) async {
    try {
      final formData = await _localDataSource.getEspbFormDataBySpbNumber(spbNumber);
      
      if (formData == null) {
        return Left(CacheFailure('ESPB form data not found for SPB: $spbNumber'));
      }
      
      return Right(formData.isSynced);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to get sync status: $e'));
    }
  }
  
  /// Validate that all required fields are present
  bool _validateFormData(EspbFormData formData) {
    // Basic validation for required fields
    if (formData.noSpb.isEmpty) return false;
    if (formData.status.isEmpty) return false;
    if (formData.createdBy.isEmpty) return false;
    
    // Status-specific validation
    if (formData.status == "2") { // Kendala
      // For kendala, we need reason and handling flag
      if (formData.alasan == null || formData.alasan!.isEmpty) return false;
      if (formData.isAnyHandlingEx == null) return false;
    }
    
    return true;
  }
}