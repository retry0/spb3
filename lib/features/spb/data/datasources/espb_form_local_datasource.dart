import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/database_helper.dart';
import '../../../../core/utils/logger.dart';
import '../models/espb_form_data.dart';

abstract class EspbFormLocalDataSource {
  /// Save ESPB form data to local database
  Future<void> saveEspbFormData(EspbFormData formData);
  
  /// Get all unsynced ESPB form data
  Future<List<EspbFormData>> getUnsyncedEspbFormData();
  
  /// Get ESPB form data by SPB number
  Future<EspbFormData?> getEspbFormDataBySpbNumber(String spbNumber);
  
  /// Mark ESPB form data as synced
  Future<void> markAsSynced(String spbNumber);
  
  /// Update sync status and error information
  Future<void> updateSyncStatus(String spbNumber, bool isSynced, String? errorMessage);
  
  /// Increment retry count for a specific SPB
  Future<void> incrementRetryCount(String spbNumber);
  
  /// Get all ESPB form data
  Future<List<EspbFormData>> getAllEspbFormData();
}

class EspbFormLocalDataSourceImpl implements EspbFormLocalDataSource {
  final DatabaseHelper _dbHelper;
  
  EspbFormLocalDataSourceImpl({required DatabaseHelper dbHelper}) : _dbHelper = dbHelper;
  
  @override
  Future<void> saveEspbFormData(EspbFormData formData) async {
    try {
      // Check if record already exists
      final existingData = await getEspbFormDataBySpbNumber(formData.noSpb);
      
      if (existingData != null) {
        // Update existing record
        await _dbHelper.update(
          'espb_form_data',
          formData.toDatabase(),
          where: 'no_spb = ?',
          whereArgs: [formData.noSpb],
        );
        AppLogger.info('Updated ESPB form data for SPB: ${formData.noSpb}');
      } else {
        // Insert new record
        await _dbHelper.insert('espb_form_data', formData.toDatabase());
        AppLogger.info('Saved new ESPB form data for SPB: ${formData.noSpb}');
      }
    } catch (e) {
      AppLogger.error('Failed to save ESPB form data: $e');
      throw CacheException('Failed to save ESPB form data: $e');
    }
  }
  
  @override
  Future<List<EspbFormData>> getUnsyncedEspbFormData() async {
    try {
      final results = await _dbHelper.query(
        'espb_form_data',
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC', // Oldest first for FIFO processing
      );
      
      return results.map((data) => EspbFormData.fromDatabase(data)).toList();
    } catch (e) {
      AppLogger.error('Failed to get unsynced ESPB form data: $e');
      throw CacheException('Failed to get unsynced ESPB form data: $e');
    }
  }
  
  @override
  Future<EspbFormData?> getEspbFormDataBySpbNumber(String spbNumber) async {
    try {
      final results = await _dbHelper.query(
        'espb_form_data',
        where: 'no_spb = ?',
        whereArgs: [spbNumber],
        limit: 1,
      );
      
      if (results.isEmpty) {
        return null;
      }
      
      return EspbFormData.fromDatabase(results.first);
    } catch (e) {
      AppLogger.error('Failed to get ESPB form data by SPB number: $e');
      throw CacheException('Failed to get ESPB form data by SPB number: $e');
    }
  }
  
  @override
  Future<void> markAsSynced(String spbNumber) async {
    try {
      await _dbHelper.update(
        'espb_form_data',
        {
          'is_synced': 1,
          'last_error': null,
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'no_spb = ?',
        whereArgs: [spbNumber],
      );
      
      AppLogger.info('Marked ESPB form data as synced for SPB: $spbNumber');
    } catch (e) {
      AppLogger.error('Failed to mark ESPB form data as synced: $e');
      throw CacheException('Failed to mark ESPB form data as synced: $e');
    }
  }
  
  @override
  Future<void> updateSyncStatus(String spbNumber, bool isSynced, String? errorMessage) async {
    try {
      await _dbHelper.update(
        'espb_form_data',
        {
          'is_synced': isSynced ? 1 : 0,
          'last_error': errorMessage,
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'no_spb = ?',
        whereArgs: [spbNumber],
      );
      
      AppLogger.info('Updated sync status for SPB: $spbNumber, isSynced: $isSynced');
      if (errorMessage != null) {
        AppLogger.warning('Sync error for SPB $spbNumber: $errorMessage');
      }
    } catch (e) {
      AppLogger.error('Failed to update sync status: $e');
      throw CacheException('Failed to update sync status: $e');
    }
  }
  
  @override
  Future<void> incrementRetryCount(String spbNumber) async {
    try {
      // Get current record to get the current retry count
      final currentData = await getEspbFormDataBySpbNumber(spbNumber);
      if (currentData == null) {
        throw CacheException('ESPB form data not found for SPB: $spbNumber');
      }
      
      // Increment retry count
      final newRetryCount = currentData.retryCount + 1;
      
      await _dbHelper.update(
        'espb_form_data',
        {
          'retry_count': newRetryCount,
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'no_spb = ?',
        whereArgs: [spbNumber],
      );
      
      AppLogger.info('Incremented retry count for SPB: $spbNumber, new count: $newRetryCount');
    } catch (e) {
      AppLogger.error('Failed to increment retry count: $e');
      throw CacheException('Failed to increment retry count: $e');
    }
  }
  
  @override
  Future<List<EspbFormData>> getAllEspbFormData() async {
    try {
      final results = await _dbHelper.query(
        'espb_form_data',
        orderBy: 'timestamp DESC', // Newest first
      );
      
      return results.map((data) => EspbFormData.fromDatabase(data)).toList();
    } catch (e) {
      AppLogger.error('Failed to get all ESPB form data: $e');
      throw CacheException('Failed to get all ESPB form data: $e');
    }
  }
}