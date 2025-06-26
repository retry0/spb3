import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/espb_form_data.dart';

abstract class EspbFormRepository {
  /// Save ESPB form data locally and attempt to sync if online
  /// 
  /// Returns success or failure with error message
  Future<Either<Failure, bool>> saveEspbFormData(EspbFormData formData);
  
  /// Get all ESPB form data
  Future<Either<Failure, List<EspbFormData>>> getAllEspbFormData();
  
  /// Get all unsynced ESPB form data
  Future<Either<Failure, List<EspbFormData>>> getUnsyncedEspbFormData();
  
  /// Sync all unsynced ESPB form data
  /// 
  /// Returns the number of successfully synced items
  Future<Either<Failure, int>> syncUnsyncedEspbFormData();
  
  /// Sync a specific ESPB form data
  Future<Either<Failure, bool>> syncEspbFormData(String spbNumber);
  
  /// Check if there are any unsynced ESPB form data
  Future<bool> hasUnsyncedData();
  
  /// Get sync status for a specific SPB
  Future<Either<Failure, bool>> getSyncStatus(String spbNumber);
}