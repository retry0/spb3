import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/espb_form_repository.dart';

class SyncEspbFormUseCase {
  final EspbFormRepository repository;
  
  SyncEspbFormUseCase(this.repository);
  
  /// Sync all unsynced ESPB form data
  /// 
  /// Returns the number of successfully synced items
  Future<Either<Failure, int>> call() async {
    return await repository.syncUnsyncedEspbFormData();
  }
  
  /// Sync a specific ESPB form data
  Future<Either<Failure, bool>> syncSpecific(String spbNumber) async {
    if (spbNumber.isEmpty) {
      return Left(ValidationFailure('SPB number is required'));
    }
    
    return await repository.syncEspbFormData(spbNumber);
  }
  
  /// Check if there are any unsynced ESPB form data
  Future<bool> hasUnsyncedData() async {
    return await repository.hasUnsyncedData();
  }
}