import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/espb_form_model.dart';
import '../repositories/espb_repository.dart';

class SaveEspbFormUseCase {
  final EspbRepository repository;

  SaveEspbFormUseCase(this.repository);

  Future<Either<Failure, bool>> call(EspbFormModel formData) async {
    // Validate form data
    final validationError = _validateFormData(formData);
    if (validationError != null) {
      return Left(ValidationFailure(validationError));
    }

    return await repository.saveEspbForm(formData);
  }

  String? _validateFormData(EspbFormModel formData) {
    if (formData.noSpb.isEmpty) {
      return 'SPB number is required';
    }

    if (formData.createdBy.isEmpty) {
      return 'Creator information is required';
    }

    if (formData.latitude.isEmpty || formData.longitude.isEmpty) {
      return 'Location coordinates are required';
    }

    // Validate status (should be "1" for accept or "2" for kendala)
    if (formData.status != "1" && formData.status != "2") {
      return 'Invalid status value. Expected "1" for accept or "2" for kendala';
    }

    // If status is "2" (kendala), alasan should be provided
    if (formData.status == "2" && (formData.alasan == null || formData.alasan!.isEmpty)) {
      return 'Reason is required for kendala status';
    }

    // Validate isAnyHandlingEx (should be "0" or "1")
    if (formData.isAnyHandlingEx != "0" && formData.isAnyHandlingEx != "1") {
      return 'Invalid handling value. Expected "0" or "1"';
    }

    return null;
  }
}