import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/spb_repository.dart';

class SyncSpbDataUseCase {
  final SpbRepository repository;

  SyncSpbDataUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String driver,
    required String kdVendor,
  }) async {
    // Validate inputs
    if (driver.isEmpty) {
      return Left(ValidationFailure('Driver information is required'));
    }

    if (kdVendor.isEmpty) {
      return Left(ValidationFailure('Vendor information is required'));
    }

    return await repository.syncSpbData(driver: driver, kdVendor: kdVendor);
  }
}
