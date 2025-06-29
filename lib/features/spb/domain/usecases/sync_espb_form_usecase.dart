import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/espb_repository.dart';

class SyncEspbFormUseCase {
  final EspbRepository repository;

  SyncEspbFormUseCase(this.repository);

  Future<Either<Failure, bool>> call(String noSpb) async {
    if (noSpb.isEmpty) {
      return Left(ValidationFailure('SPB number is required'));
    }

    return await repository.syncEspbForm(noSpb);
  }
}