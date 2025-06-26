import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/espb_form_data.dart';

abstract class EspbFormRepository {
  /// Saves form data to local database
  ///
  /// Returns a [Future] that completes with [EspbFormData] if successful, [Failure] otherwise
  Future<Either<Failure, EspbFormData>> saveFormData(EspbFormData formData);

  /// Syncs form data with remote API
  ///
  /// Returns a [Future] that completes with [EspbFormData] if successful, [Failure] otherwise
  Future<Either<Failure, EspbFormData>> syncFormData(String formId);

  /// Syncs all pending form data with remote API
  ///
  /// Returns a [Future] that completes with the number of successfully synced items if successful, [Failure] otherwise
  Future<Either<Failure, int>> syncAllPendingForms();

  /// Gets form data by ID
  ///
  /// Returns a [Future] that completes with [EspbFormData] if successful, [Failure] otherwise
  Future<Either<Failure, EspbFormData>> getFormData(String formId);

  /// Gets all pending form data
  ///
  /// Returns a [Future] that completes with a list of [EspbFormData] if successful, [Failure] otherwise
  Future<Either<Failure, List<EspbFormData>>> getAllPendingForms();

  /// Gets all form data for a specific SPB
  ///
  /// Returns a [Future] that completes with a list of [EspbFormData] if successful, [Failure] otherwise
  Future<Either<Failure, List<EspbFormData>>> getFormDataForSpb(String noSpb);
}