import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/spb_model.dart';

class GenerateSpbQrCodeUseCase {
  GenerateSpbQrCodeUseCase();

  Either<Failure, String> call({
    required SpbModel spb,
    required String driver,
    required String kdVendor,
  }) {
    try {
      // Validate inputs
      if (spb.noSpb.isEmpty) {
        return Left(ValidationFailure('SPB number is required'));
      }

      if (driver.isEmpty) {
        return Left(ValidationFailure('Driver information is required'));
      }

      if (kdVendor.isEmpty) {
        return Left(ValidationFailure('Vendor information is required'));
      }

      // Generate QR code content by concatenating data with | separator
      final qrContent = [
        spb.noSpb,
        spb.tglAntarBuah,
        spb.millTujuan,
        spb.status,
        driver,
        kdVendor,
        spb.keterangan ?? '',
      ].join('|');

      return Right(qrContent);
    } catch (e) {
      return Left(ServerFailure('Failed to generate QR code: $e'));
    }
  }
}
