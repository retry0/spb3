import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/espb_form_model.dart';
import '../repositories/espb_repository.dart';

class GetEspbFormUseCase {
  final EspbRepository repository;

  GetEspbFormUseCase(this.repository);

  Future<Either<Failure, EspbFormModel?>> call(String noSpb) async {
    if (noSpb.isEmpty) {
      return Left(ValidationFailure('SPB number is required'));
    }

    return await repository.getEspbForm(noSpb);
  }
}