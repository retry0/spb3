import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/spb_model.dart';

abstract class SpbQrRepository {
  /// Save QR code sync status to local storage
  Future<Either<Failure, bool>> saveQrCodeSyncStatus(String spbNumber, bool synced);

  /// Get QR code sync status from local storage
  Future<Either<Failure, bool>> getQrCodeSyncStatus(String spbNumber);

  /// Sync QR code with backend
  Future<Either<Failure, bool>> syncQrCodeWithBackend(
    SpbModel spb,
    String driver,
    String kdVendor,
  );
}