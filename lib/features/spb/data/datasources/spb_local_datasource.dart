import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/database_helper.dart';
import '../models/spb_model.dart';

abstract class SpbLocalDataSource {
  /// Gets all SPB data from the local database
  Future<List<SpbModel>> getAllSpb();

  /// Gets SPB data for a specific driver
  Future<List<SpbModel>> getSpbForDriver({
    required String driver,
    required String kdVendor,
  });

  /// Saves SPB data to the local database
  Future<void> saveSpbList(
    List<SpbModel> spbList, {
    required String driver,
    required String kdVendor,
  });

  /// Marks SPB data as synced
  Future<void> markAsSynced(String noSpb);

  /// Gets all unsynced SPB data
  Future<List<SpbModel>> getUnsyncedSpb();

  /// Clears all SPB data
  Future<void> clearAllSpb();
}

class SpbLocalDataSourceImpl implements SpbLocalDataSource {
  final DatabaseHelper dbHelper;

  SpbLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<List<SpbModel>> getAllSpb() async {
    try {
      final results = await dbHelper.query(
        'spb_data',
        orderBy: 'created_at DESC',
      );

      return results.map((data) => SpbModel.fromDatabase(data)).toList();
    } catch (e) {
      throw CacheException('Failed to get SPB data from local storage: $e');
    }
  }

  @override
  Future<List<SpbModel>> getSpbForDriver({
    required String driver,
    required String kdVendor,
  }) async {
    try {
      final results = await dbHelper.query(
        'spb_data',
        where: 'driver = ? AND kode_vendor = ?',
        whereArgs: [driver, kdVendor],
        orderBy: 'created_at DESC',
      );

      return results.map((data) => SpbModel.fromDatabase(data)).toList();
    } catch (e) {
      throw CacheException('Failed to get SPB data for driver: $e');
    }
  }

  @override
  Future<void> saveSpbList(
    List<SpbModel> spbList, {
    required String driver,
    required String kdVendor,
  }) async {
    try {
      // Use a transaction for better performance
      await dbHelper.transaction((txn) async {
        for (final spb in spbList) {
          // Check if SPB already exists
          final existingResults = await txn.query(
            'spb_data',
            where: 'no_spb = ?',
            whereArgs: [spb.noSpb],
            limit: 1,
          );

          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final data = spb.toDatabase();

          // Add driver and vendor info
          data['driver'] = driver;
          data['kode_vendor'] = kdVendor;

          // Add metadata
          data['updated_at'] = now;

          if (existingResults.isEmpty) {
            // Insert new record
            data['created_at'] = now;
            await txn.insert('spb_data', data);
          } else {
            // Update existing record
            await txn.update(
              'spb_data',
              data,
              where: 'no_spb = ?',
              whereArgs: [spb.noSpb],
            );
          }
        }
      });
    } catch (e) {
      throw CacheException('Failed to save SPB data to local storage: $e');
    }
  }

  @override
  Future<void> markAsSynced(String noSpb) async {
    try {
      await dbHelper.update(
        'spb_data',
        {'is_synced': 1},
        where: 'no_spb = ?',
        whereArgs: [noSpb],
      );
    } catch (e) {
      throw CacheException('Failed to mark SPB as synced: $e');
    }
  }

  @override
  Future<List<SpbModel>> getUnsyncedSpb() async {
    try {
      final results = await dbHelper.query(
        'spb_data',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      return results.map((data) => SpbModel.fromDatabase(data)).toList();
    } catch (e) {
      throw CacheException('Failed to get unsynced SPB data: $e');
    }
  }

  @override
  Future<void> clearAllSpb() async {
    try {
      await dbHelper.delete('spb_data');
    } catch (e) {
      throw CacheException('Failed to clear SPB data: $e');
    }
  }
}