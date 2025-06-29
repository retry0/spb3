import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/espb_repository.dart';

class MigrateEspbFormsUseCase {
  final EspbRepository repository;

  MigrateEspbFormsUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.migrateEspbFormsFromSharedPreferences();
  }
}