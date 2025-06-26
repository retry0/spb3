import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/spb_model.dart';
import '../repositories/spb_repository.dart';

class GetSpbForDriverUseCase {
  final SpbRepository repository;

  GetSpbForDriverUseCase(this.repository);

  Future<Either<Failure, List<SpbModel>>> call({
    required String driver,
    required String kdVendor,
    bool forceRefresh = false,
  }) async {
    // Validate inputs
    if (driver.isEmpty) {
      return Left(ValidationFailure('Driver information is required'));
    }

    if (kdVendor.isEmpty) {
      return Left(ValidationFailure('Vendor information is required'));
    }

    return await repository.getSpbForDriver(
      driver: driver,
      kdVendor: kdVendor,
      forceRefresh: forceRefresh,
    );
  }
}
