import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/spb_model.dart';

abstract class SpbRepository {
  /// Gets SPB data for a driver
  ///
  /// Returns a [List<SpbModel>] if successful, [Failure] otherwise
  Future<Either<Failure, List<SpbModel>>> getSpbForDriver({
    required String driver,
    required String kdVendor,
    bool forceRefresh = false,
  });

  /// Syncs SPB data with the remote server
  ///
  /// Returns [void] if successful, [Failure] otherwise
  Future<Either<Failure, void>> syncSpbData({
    required String driver,
    required String kdVendor,
  });

  /// Clears all SPB data from local storage
  ///
  /// Returns [void] if successful, [Failure] otherwise
  Future<Either<Failure, void>> clearAllSpbData();
}