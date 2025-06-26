import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/espb_form_data.dart';
import '../repositories/espb_form_repository.dart';

class SaveEspbFormUseCase {
  final EspbFormRepository repository;
  
  SaveEspbFormUseCase(this.repository);
  
  /// Save ESPB form data and attempt to sync if online
  Future<Either<Failure, bool>> call(EspbFormData formData) async {
    // Validate input
    if (formData.noSpb.isEmpty) {
      return Left(ValidationFailure('SPB number is required'));
    }
    
    if (formData.status.isEmpty) {
      return Left(ValidationFailure('Status is required'));
    }
    
    if (formData.createdBy.isEmpty) {
      return Left(ValidationFailure('Created by is required'));
    }
    
    // Status-specific validation
    if (formData.status == "2") { // Kendala
      if (formData.alasan == null || formData.alasan!.isEmpty) {
        return Left(ValidationFailure('Reason is required for kendala'));
      }
      
      if (formData.isAnyHandlingEx == null) {
        return Left(ValidationFailure('Driver/vehicle change flag is required for kendala'));
      }
    }
    
    // Save and sync
    return await repository.saveEspbFormData(formData);
  }
}