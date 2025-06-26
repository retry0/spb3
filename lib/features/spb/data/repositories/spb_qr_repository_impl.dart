import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/repositories/spb_qr_repository.dart';
import '../models/spb_model.dart';

class SpbQrRepositoryImpl implements SpbQrRepository {
  final Connectivity _connectivity;
  final SharedPreferences _prefs;

  SpbQrRepositoryImpl({
    required Connectivity connectivity,
    required SharedPreferences prefs,
  }) : _connectivity = connectivity,
       _prefs = prefs;

  @override
  Future<Either<Failure, bool>> saveQrCodeSyncStatus(
    String spbNumber,
    bool synced,
  ) async {
    try {
      final key = 'qr_sync_$spbNumber';
      await _prefs.setBool(key, synced);
      return const Right(true);
    } catch (e) {
      return Left(CacheFailure('Failed to save QR code sync status: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> getQrCodeSyncStatus(String spbNumber) async {
    try {
      final key = 'qr_sync_$spbNumber';
      final isSynced = _prefs.getBool(key) ?? false;
      return Right(isSynced);
    } catch (e) {
      return Left(CacheFailure('Failed to get QR code sync status: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> syncQrCodeWithBackend(
    SpbModel spb,
    String driver,
    String kdVendor,
  ) async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasConnectivity =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (!hasConnectivity) {
        return Left(NetworkFailure('No internet connection available'));
      }

      // In a real app, you would make an API call here
      // For demo purposes, we'll simulate a successful sync
      await Future.delayed(const Duration(seconds: 1));

      // Save sync status to local storage
      await saveQrCodeSyncStatus(spb.noSpb, true);

      return const Right(true);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to sync QR code with backend: $e'));
    }
  }
}
