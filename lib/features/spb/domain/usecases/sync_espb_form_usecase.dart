import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/espb_form_data.dart';
import '../repositories/espb_form_repository.dart';

class SyncEspbFormUseCase {
  final EspbFormRepository repository;

  SyncEspbFormUseCase({required this.repository});

  /// Syncs a specific form with the remote API
  ///
  /// Returns [EspbFormData] if successful, [Failure] otherwise
  Future<Either<Failure, EspbFormData>> call(String formId) async {
    return await repository.syncFormData(formId);
  }
  
  /// Syncs all pending forms with the remote API
  ///
  /// Returns the number of successfully synced items if successful, [Failure] otherwise
  Future<Either<Failure, int>> syncAll() async {
    return await repository.syncAllPendingForms();
  }
}