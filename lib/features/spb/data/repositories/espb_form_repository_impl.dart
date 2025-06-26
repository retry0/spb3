import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

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
  final Uuid _uuid;

  // For background sync
  Timer? _syncTimer;
  bool _isSyncing = false;
  final Duration _syncInterval = const Duration(minutes: 5);
  
  // For retry mechanism
  final int _maxRetries = 5;
  final Duration _initialBackoff = const Duration(seconds: 5);

  EspbFormRepositoryImpl({
    required EspbFormLocalDataSource localDataSource,
    required EspbFormRemoteDataSource remoteDataSource,
    required Connectivity connectivity,
    required Uuid uuid,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _connectivity = connectivity,
       _uuid = uuid {
    // Start background sync
    _startBackgroundSync();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  @override
  Future<Either<Failure, EspbFormData>> saveFormData(EspbFormData formData) async {
    try {
      // Validate form data
      final validationError = EspbFormData.validate(formData);
      if (validationError != null) {
        return Left(ValidationFailure(validationError));
      }
      
      // Generate ID if not provided
      final dataToSave = formData.id.isEmpty 
          ? formData.copyWith(id: _uuid.v4(), createdAt: DateTime.now())
          : formData;
      
      // Save to local database
      final savedData = await _localDataSource.saveFormData(dataToSave);
      
      // Try to sync immediately if online
      final isConnected = await _checkConnectivity();
      if (isConnected) {
        // Don't wait for sync to complete
        _syncFormData(savedData.id).then((_) {
          AppLogger.info('Background sync initiated for form: ${savedData.id}');
        }).catchError((e) {
          AppLogger.error('Background sync failed for form: ${savedData.id}', e);
        });
      }
      
      return Right(savedData);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to save form data: $e'));
    }
  }

  @override
  Future<Either<Failure, EspbFormData>> syncFormData(String formId) async {
    try {
      // Check connectivity
      final isConnected = await _checkConnectivity();
      if (!isConnected) {
        return Left(NetworkFailure('No internet connection available'));
      }
      
      // Get form data from local database
      final formData = await _localDataSource.getFormData(formId);
      if (formData == null) {
        return Left(CacheFailure('Form data not found'));
      }
      
      // If already synced, return success
      if (formData.isSynced) {
        return Right(formData);
      }
      
      // Check if already processed on server to avoid duplicates
      final isProcessed = await _remoteDataSource.checkFormProcessed(
        formData.noSpb, 
        formData.status,
      );
      
      if (isProcessed) {
        // Already processed on server, update local status
        final updatedForm = await _localDataSource.updateFormSyncStatus(
          formId,
          isSynced: true,
          syncedAt: DateTime.now(),
        );
        
        AppLogger.info('Form already processed on server: ${formData.id}');
        return Right(updatedForm);
      }
      
      // Submit to remote API
      await _remoteDataSource.submitFormData(formData);
      
      // Update sync status in local database
      final updatedForm = await _localDataSource.updateFormSyncStatus(
        formId,
        isSynced: true,
        syncedAt: DateTime.now(),
      );
      
      AppLogger.info('Form synced successfully: ${formData.id}');
      return Right(updatedForm);
    } on NetworkException catch (e) {
      // Update retry count and error message
      try {
        final formData = await _localDataSource.getFormData(formId);
        if (formData != null) {
          await _localDataSource.updateFormSyncStatus(
            formId,
            isSynced: false,
            lastError: e.message,
            retryCount: formData.retryCount + 1,
          );
        }
      } catch (_) {
        // Ignore errors in error handling
      }
      
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      // Update retry count and error message
      try {
        final formData = await _localDataSource.getFormData(formId);
        if (formData != null) {
          await _localDataSource.updateFormSyncStatus(
            formId,
            isSynced: false,
            lastError: e.message,
            retryCount: formData.retryCount + 1,
          );
        }
      } catch (_) {
        // Ignore errors in error handling
      }
      
      return Left(ServerFailure(e.message));
    } on TimeoutException catch (e) {
      // Update retry count and error message
      try {
        final formData = await _localDataSource.getFormData(formId);
        if (formData != null) {
          await _localDataSource.updateFormSyncStatus(
            formId,
            isSynced: false,
            lastError: e.message,
            retryCount: formData.retryCount + 1,
          );
        }
      } catch (_) {
        // Ignore errors in error handling
      }
      
      return Left(TimeoutFailure(e.message));
    } catch (e) {
      // Update retry count and error message
      try {
        final formData = await _localDataSource.getFormData(formId);
        if (formData != null) {
          await _localDataSource.updateFormSyncStatus(
            formId,
            isSynced: false,
            lastError: e.toString(),
            retryCount: formData.retryCount + 1,
          );
        }
      } catch (_) {
        // Ignore errors in error handling
      }
      
      return Left(ServerFailure('Failed to sync form data: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> syncAllPendingForms() async {
    try {
      // Check if already syncing
      if (_isSyncing) {
        return const Right(0);
      }
      
      _isSyncing = true;
      
      try {
        // Check connectivity
        final isConnected = await _checkConnectivity();
        if (!isConnected) {
          return Left(NetworkFailure('No internet connection available'));
        }
        
        // Get all pending forms
        final pendingForms = await _localDataSource.getAllPendingForms();
        
        if (pendingForms.isEmpty) {
          return const Right(0);
        }
        
        int successCount = 0;
        
        // Process each form
        for (final form in pendingForms) {
          // Skip forms that have exceeded max retries
          if (form.retryCount >= _maxRetries) {
            AppLogger.warning('Form exceeded max retries: ${form.id}');
            continue;
          }
          
          try {
            // Check if already processed on server
            final isProcessed = await _remoteDataSource.checkFormProcessed(
              form.noSpb, 
              form.status,
            );
            
            if (isProcessed) {
              // Already processed on server, update local status
              await _localDataSource.updateFormSyncStatus(
                form.id,
                isSynced: true,
                syncedAt: DateTime.now(),
              );
              
              successCount++;
              AppLogger.info('Form already processed on server: ${form.id}');
              continue;
            }
            
            // Submit to remote API
            await _remoteDataSource.submitFormData(form);
            
            // Update sync status
            await _localDataSource.updateFormSyncStatus(
              form.id,
              isSynced: true,
              syncedAt: DateTime.now(),
            );
            
            successCount++;
            AppLogger.info('Form synced successfully: ${form.id}');
          } catch (e) {
            // Update retry count and error message
            await _localDataSource.updateFormSyncStatus(
              form.id,
              isSynced: false,
              lastError: e.toString(),
              retryCount: form.retryCount + 1,
            );
            
            AppLogger.error('Failed to sync form: ${form.id}', e);
          }
          
          // Add a small delay between requests to avoid overwhelming the server
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        return Right(successCount);
      } finally {
        _isSyncing = false;
      }
    } catch (e) {
      _isSyncing = false;
      return Left(ServerFailure('Failed to sync pending forms: $e'));
    }
  }

  @override
  Future<Either<Failure, EspbFormData>> getFormData(String formId) async {
    try {
      final formData = await _localDataSource.getFormData(formId);
      if (formData == null) {
        return Left(CacheFailure('Form data not found'));
      }
      
      return Right(formData);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to get form data: $e'));
    }
  }

  @override
  Future<Either<Failure, List<EspbFormData>>> getAllPendingForms() async {
    try {
      final pendingForms = await _localDataSource.getAllPendingForms();
      return Right(pendingForms);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to get pending forms: $e'));
    }
  }

  @override
  Future<Either<Failure, List<EspbFormData>>> getFormDataForSpb(String noSpb) async {
    try {
      final forms = await _localDataSource.getFormDataForSpb(noSpb);
      return Right(forms);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to get form data for SPB: $e'));
    }
  }

  // Private helper methods
  
  Future<bool> _checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.isNotEmpty && 
           !connectivityResult.contains(ConnectivityResult.none);
  }
  
  void _handleConnectivityChange(List<ConnectivityResult> result) {
    final isConnected = result.isNotEmpty && 
                        !result.contains(ConnectivityResult.none);
    
    if (isConnected && !_isSyncing) {
      // Trigger sync when connectivity is restored
      syncAllPendingForms().then((result) {
        result.fold(
          (failure) => AppLogger.error('Auto-sync failed: ${failure.message}'),
          (count) => AppLogger.info('Auto-sync completed: $count items synced'),
        );
      });
    }
  }
  
  void _startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      if (!_isSyncing) {
        syncAllPendingForms().then((result) {
          result.fold(
            (failure) => AppLogger.error('Background sync failed: ${failure.message}'),
            (count) => count > 0 
                ? AppLogger.info('Background sync completed: $count items synced')
                : null, // Don't log if nothing was synced
          );
        });
      }
    });
  }
  
  // Retry with exponential backoff
  Future<Either<Failure, EspbFormData>> _retryWithBackoff(
    String formId,
    Future<Either<Failure, EspbFormData>> Function() operation,
    int attempt,
  ) async {
    if (attempt >= _maxRetries) {
      return Left(ServerFailure('Max retry attempts reached'));
    }
    
    // Calculate backoff duration
    final backoffDuration = _initialBackoff * (1 << attempt);
    
    try {
      return await operation();
    } catch (e) {
      // Wait before retrying
      await Future.delayed(backoffDuration);
      
      // Retry with incremented attempt
      return _retryWithBackoff(formId, operation, attempt + 1);
    }
  }
  
  // Dispose resources
  void dispose() {
    _syncTimer?.cancel();
  }
}