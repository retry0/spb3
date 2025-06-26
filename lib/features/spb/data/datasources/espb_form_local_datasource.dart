import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/database_helper.dart';
import '../../../../core/utils/logger.dart';
import '../models/espb_form_data.dart';

abstract class EspbFormLocalDataSource {
  /// Saves form data to local database
  ///
  /// Throws [CacheException] if saving fails
  Future<EspbFormData> saveFormData(EspbFormData formData);

  /// Gets form data by ID
  ///
  /// Throws [CacheException] if retrieval fails
  /// Returns null if no data found
  Future<EspbFormData?> getFormData(String formId);

  /// Gets all pending form data
  ///
  /// Throws [CacheException] if retrieval fails
  Future<List<EspbFormData>> getAllPendingForms();

  /// Gets all form data for a specific SPB
  ///
  /// Throws [CacheException] if retrieval fails
  Future<List<EspbFormData>> getFormDataForSpb(String noSpb);

  /// Updates form data sync status
  ///
  /// Throws [CacheException] if update fails
  Future<EspbFormData> updateFormSyncStatus(
    String formId, {
    required bool isSynced,
    DateTime? syncedAt,
    String? lastError,
    int? retryCount,
  });
}

class EspbFormLocalDataSourceImpl implements EspbFormLocalDataSource {
  final DatabaseHelper _dbHelper;

  EspbFormLocalDataSourceImpl({required DatabaseHelper dbHelper}) : _dbHelper = dbHelper;

  @override
  Future<EspbFormData> saveFormData(EspbFormData formData) async {
    try {
      await _dbHelper.insert('espb_form_data', formData.toDatabase());
      return formData;
    } catch (e) {
      AppLogger.error('Failed to save form data to local storage: $e');
      throw CacheException('Failed to save form data: $e');
    }
  }

  @override
  Future<EspbFormData?> getFormData(String formId) async {
    try {
      final results = await _dbHelper.query(
        'espb_form_data',
        where: 'id = ?',
        whereArgs: [formId],
        limit: 1,
      );

      if (results.isEmpty) {
        return null;
      }

      return EspbFormData.fromDatabase(results.first);
    } catch (e) {
      AppLogger.error('Failed to get form data from local storage: $e');
      throw CacheException('Failed to get form data: $e');
    }
  }

  @override
  Future<List<EspbFormData>> getAllPendingForms() async {
    try {
      final results = await _dbHelper.query(
        'espb_form_data',
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'created_at ASC',
      );

      return results.map((data) => EspbFormData.fromDatabase(data)).toList();
    } catch (e) {
      AppLogger.error('Failed to get pending forms from local storage: $e');
      throw CacheException('Failed to get pending forms: $e');
    }
  }

  @override
  Future<List<EspbFormData>> getFormDataForSpb(String noSpb) async {
    try {
      final results = await _dbHelper.query(
        'espb_form_data',
        where: 'no_spb = ?',
        whereArgs: [noSpb],
        orderBy: 'created_at DESC',
      );

      return results.map((data) => EspbFormData.fromDatabase(data)).toList();
    } catch (e) {
      AppLogger.error('Failed to get form data for SPB from local storage: $e');
      throw CacheException('Failed to get form data for SPB: $e');
    }
  }

  @override
  Future<EspbFormData> updateFormSyncStatus(
    String formId, {
    required bool isSynced,
    DateTime? syncedAt,
    String? lastError,
    int? retryCount,
  }) async {
    try {
      final now = DateTime.now();
      final updates = {
        'is_synced': isSynced ? 1 : 0,
        'synced_at': syncedAt?.millisecondsSinceEpoch ~/ 1000 ?? (isSynced ? now.millisecondsSinceEpoch ~/ 1000 : null),
        'updated_at': now.millisecondsSinceEpoch ~/ 1000,
      };

      if (lastError != null) {
        updates['last_error'] = lastError;
      }

      if (retryCount != null) {
        updates['retry_count'] = retryCount;
      } else if (!isSynced && lastError != null) {
        // Increment retry count if sync failed
        final currentForm = await getFormData(formId);
        if (currentForm != null) {
          updates['retry_count'] = currentForm.retryCount + 1;
        }
      }

      await _dbHelper.update(
        'espb_form_data',
        updates,
        where: 'id = ?',
        whereArgs: [formId],
      );

      // Get updated form data
      final updatedForm = await getFormData(formId);
      if (updatedForm == null) {
        throw CacheException('Form data not found after update');
      }

      return updatedForm;
    } catch (e) {
      AppLogger.error('Failed to update form sync status: $e');
      throw CacheException('Failed to update form sync status: $e');
    }
  }
}