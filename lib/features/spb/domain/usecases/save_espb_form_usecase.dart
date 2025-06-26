import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/espb_form_data.dart';
import '../repositories/espb_form_repository.dart';

class SaveEspbFormUseCase {
  final EspbFormRepository repository;
  final Uuid uuid;

  SaveEspbFormUseCase({
    required this.repository,
    required this.uuid,
  });

  /// Saves ESPB form data
  ///
  /// For acceptance forms (cek_espb_page.dart):
  /// - status should be "1"
  /// - alasan and isDriverOrVehicleChanged are not required
  ///
  /// For kendala forms (kendala_form_page.dart):
  /// - status should be "2"
  /// - alasan is required if isDriverOrVehicleChanged is true
  ///
  /// Returns [EspbFormData] if successful, [Failure] otherwise
  Future<Either<Failure, EspbFormData>> call({
    required String noSpb,
    required EspbFormType formType,
    required String status,
    String? alasan,
    bool? isDriverOrVehicleChanged,
    required String latitude,
    required String longitude,
    required String createdBy,
  }) async {
    try {
      // Create form data object
      final formData = EspbFormData(
        id: uuid.v4(),
        noSpb: noSpb,
        formType: formType,
        status: status,
        alasan: alasan,
        isDriverOrVehicleChanged: isDriverOrVehicleChanged,
        latitude: latitude,
        longitude: longitude,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        isSynced: false,
        retryCount: 0,
      );
      
      // Validate form data
      final validationError = EspbFormData.validate(formData);
      if (validationError != null) {
        return Left(ValidationFailure(validationError));
      }
      
      // Save form data
      return repository.saveFormData(formData);
    } catch (e) {
      return Left(ServerFailure('Failed to save form data: $e'));
    }
  }
}