import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/espb_repository.dart';

class SyncAllPendingEspbFormsUseCase {
  final EspbRepository repository;

  SyncAllPendingEspbFormsUseCase(this.repository);

  Future<Either<Failure, int>> call() async {
    return await repository.syncAllPendingEspbForms();
  }
}