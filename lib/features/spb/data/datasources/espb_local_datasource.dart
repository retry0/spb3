import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/database_helper.dart';
import '../../../../core/utils/logger.dart';
import '../models/espb_form_model.dart';

abstract class EspbLocalDataSource {
  /// Gets ESPB form data for a specific SPB
  Future<EspbFormModel?> getEspbFormData(String noSpb);

  /// Saves ESPB form data to local storage
  Future<bool> saveEspbFormData(EspbFormModel formData);

  /// Gets all pending (unsynced) ESPB forms
  Future<List<EspbFormModel>> getPendingEspbForms();

  /// Marks an ESPB form as synced
  Future<void> markEspbFormAsSynced(String noSpb);

  /// Updates ESPB form sync status
  Future<void> updateEspbFormSyncStatus(
    String noSpb, {
    bool? isSynced,
    String? errorMessage,
    int? retryCount,
  });

  /// Migrates ESPB form data from SharedPreferences to SQLite
  Future<void> migrateFromSharedPreferences();
}

class EspbLocalDataSourceImpl implements EspbLocalDataSource {
  final DatabaseHelper _dbHelper;
  
  EspbLocalDataSourceImpl({required DatabaseHelper dbHelper}) : _dbHelper = dbHelper;

  @override
  Future<EspbFormModel?> getEspbFormData(String noSpb) async {
    try {
      final result = await _dbHelper.getEspbFormData(noSpb);
      if (result == null) return null;
      
      return EspbFormModel.fromDatabase(result);
    } catch (e) {
      AppLogger.error('Failed to get ESPB form data: $e');
      return null;
    }
  }

  @override
  Future<bool> saveEspbFormData(EspbFormModel formData) async {
    try {
      final data = formData.toDatabase();
      await _dbHelper.saveEspbFormData(data);
      return true;
    } catch (e) {
      AppLogger.error('Failed to save ESPB form data: $e');
      return false;
    }
  }

  @override
  Future<List<EspbFormModel>> getPendingEspbForms() async {
    try {
      final results = await _dbHelper.getPendingEspbForms();
      return results.map((data) => EspbFormModel.fromDatabase(data)).toList();
    } catch (e) {
      AppLogger.error('Failed to get pending ESPB forms: $e');
      return [];
    }
  }

  @override
  Future<void> markEspbFormAsSynced(String noSpb) async {
    try {
      await _dbHelper.markEspbFormAsSynced(noSpb);
    } catch (e) {
      AppLogger.error('Failed to mark ESPB form as synced: $e');
      throw CacheException('Failed to mark ESPB form as synced: $e');
    }
  }

  @override
  Future<void> updateEspbFormSyncStatus(
    String noSpb, {
    bool? isSynced,
    String? errorMessage,
    int? retryCount,
  }) async {
    try {
      await _dbHelper.updateEspbFormSyncStatus(
        noSpb,
        isSynced: isSynced,
        errorMessage: errorMessage,
        retryCount: retryCount,
      );
    } catch (e) {
      AppLogger.error('Failed to update ESPB form sync status: $e');
      throw CacheException('Failed to update ESPB form sync status: $e');
    }
  }

  @override
  Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys from SharedPreferences
      final allKeys = prefs.getKeys();
      
      // Filter keys related to cek_form_data
      final formDataKeys = allKeys.where((key) => key.startsWith('cek_form_data_')).toList();
      
      // Begin database transaction for better performance
      await _dbHelper.transaction((txn) async {
        for (final key in formDataKeys) {
          try {
            // Extract SPB ID from key
            final noSpb = key.replaceFirst('cek_form_data_', '');
            
            // Get form data from SharedPreferences
            final formDataJson = prefs.getString(key);
            if (formDataJson == null) continue;
            
            // Parse JSON data
            final formData = Map<String, dynamic>.from(
              Map<String, dynamic>.from(jsonDecode(formDataJson))
            );
            
            // Get additional data
            final isSynced = prefs.getBool('cek_synced_$noSpb') ?? false;
            final modifiedTimestamp = prefs.getInt('cek_modified_$noSpb');
            
            // Prepare data for SQLite
            final dbData = {
              'no_spb': noSpb,
              'status': formData['status'] ?? '1',
              'created_by': formData['createdBy'] ?? '',
              'latitude': formData['latitude'] ?? '0.0',
              'longitude': formData['longitude'] ?? '0.0',
              'alasan': formData['alasan'],
              'is_any_handling_ex': formData['isAnyHandlingEx'] ?? '0',
              'timestamp': formData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
              'is_synced': isSynced ? 1 : 0,
              'retry_count': 0,
              'created_at': modifiedTimestamp != null 
                  ? modifiedTimestamp ~/ 1000 
                  : DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            };
            
            // Insert into database
            await txn.insert(
              'espb_form_data',
              dbData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            
            // Remove from SharedPreferences after successful migration
            // Uncomment when migration is confirmed working
            // await prefs.remove(key);
            // await prefs.remove('cek_synced_$noSpb');
            // await prefs.remove('cek_modified_$noSpb');
          } catch (e) {
            AppLogger.error('Failed to migrate form data for key $key: $e');
            // Continue with next item
          }
        }
      });
      
      // Clean up pending forms list
      // Uncomment when migration is confirmed working
      // await prefs.remove('pending_cek_forms');
      
      AppLogger.info('Migration of ESPB forms from SharedPreferences completed');
    } catch (e) {
      AppLogger.error('Failed to migrate ESPB forms from SharedPreferences', e);
      throw CacheException('Failed to migrate ESPB forms: $e');
    }
  }
}