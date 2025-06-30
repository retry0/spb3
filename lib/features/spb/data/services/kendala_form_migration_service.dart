import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/storage/database_helper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/di/injection.dart';

/// Service responsible for migrating Kendala form data from SharedPreferences to SQLite
class KendalaFormMigrationService {
  final DatabaseHelper _dbHelper;
  
  // Status notifiers
  final ValueNotifier<MigrationStatus> migrationStatusNotifier = 
      ValueNotifier<MigrationStatus>(MigrationStatus.notStarted);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> totalItemsNotifier = ValueNotifier<int>(0);
  
  KendalaFormMigrationService({
    required DatabaseHelper dbHelper,
  }) : _dbHelper = dbHelper;
  
  /// Migrate all Kendala form data from SharedPreferences to SQLite
  Future<bool> migrateKendalaForms() async {
    try {
      migrationStatusNotifier.value = MigrationStatus.inProgress;
      errorMessageNotifier.value = null;
      
      // 1. Get all SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // 2. Filter keys related to Kendala forms
      final formDataKeys = allKeys.where((key) => key.startsWith('kendala_form_data_')).toList();
      final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
      
      // Update total items count
      totalItemsNotifier.value = formDataKeys.length;
      progressNotifier.value = 0;
      
      AppLogger.info('Found ${formDataKeys.length} Kendala forms to migrate');
      
      // 3. Ensure the database table exists
      await _ensureTableExists();
      
      // 4. Migrate each form
      int successCount = 0;
      for (int i = 0; i < formDataKeys.length; i++) {
        final key = formDataKeys[i];
        final spbId = key.replaceFirst('kendala_form_data_', '');
        
        try {
          // Get form data from SharedPreferences
          final formDataJson = prefs.getString(key);
          if (formDataJson == null) continue;
          
          final data = jsonDecode(formDataJson) as Map<String, dynamic>;
          
          // Get additional form metadata
          final isDriverChanged = prefs.getBool('kendala_driver_changed_$spbId') ?? false;
          final kendalaText = prefs.getString('kendala_text_$spbId') ?? '';
          final isSynced = prefs.getBool('kendala_synced_$spbId') ?? false;
          final timestamp = data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
          
          // Prepare data for SQLite
          final dbData = {
            'no_spb': spbId,
            'created_by': data['createdBy'] ?? '',
            'latitude': data['latitude'] ?? '0.0',
            'longitude': data['longitude'] ?? '0.0',
            'alasan': kendalaText,
            'is_any_handling_ex': isDriverChanged ? "1" : "0",
            'timestamp': timestamp,
            'is_synced': isSynced ? 1 : 0,
            'retry_count': 0,
            'last_error': null,
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          };
          
          // Insert into SQLite
          await _insertFormData(dbData);
          successCount++;
        } catch (e) {
          AppLogger.error('Failed to migrate form $spbId: $e');
        }
        
        // Update progress
        progressNotifier.value = i + 1;
      }
      
      // 5. Migrate pending forms list
      if (pendingForms.isNotEmpty) {
        await _migratePendingFormsList(pendingForms);
      }
      
      // 6. Verify migration
      final verificationResult = await _verifyMigration(formDataKeys);
      
      if (verificationResult) {
        migrationStatusNotifier.value = MigrationStatus.completed;
        AppLogger.info('Migration completed successfully: $successCount/${formDataKeys.length} forms migrated');
        return true;
      } else {
        migrationStatusNotifier.value = MigrationStatus.failed;
        errorMessageNotifier.value = 'Verification failed: Some data may not have been migrated correctly';
        AppLogger.error('Migration verification failed');
        return false;
      }
    } catch (e) {
      migrationStatusNotifier.value = MigrationStatus.failed;
      errorMessageNotifier.value = 'Migration failed: $e';
      AppLogger.error('Migration failed: $e');
      return false;
    }
  }
  
  /// Ensure the kendala_forms table exists in the database
  Future<void> _ensureTableExists() async {
    try {
      final db = await _dbHelper.database;
      
      // Check if table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='kendala_forms'"
      );
      
      if (tables.isEmpty) {
        // Create table if it doesn't exist
        await db.execute('''
          CREATE TABLE kendala_forms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            no_spb TEXT UNIQUE NOT NULL,
            created_by TEXT NOT NULL,
            latitude TEXT NOT NULL,
            longitude TEXT NOT NULL,
            alasan TEXT,
            is_any_handling_ex TEXT,
            timestamp INTEGER NOT NULL,
            is_synced INTEGER NOT NULL DEFAULT 0,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
        
        // Create indexes
        await db.execute(
          'CREATE INDEX idx_kendala_forms_no_spb ON kendala_forms (no_spb)'
        );
        await db.execute(
          'CREATE INDEX idx_kendala_forms_is_synced ON kendala_forms (is_synced)'
        );
        await db.execute(
          'CREATE INDEX idx_kendala_forms_timestamp ON kendala_forms (timestamp)'
        );
        
        AppLogger.info('Created kendala_forms table');
      } else {
        AppLogger.info('kendala_forms table already exists');
      }
    } catch (e) {
      AppLogger.error('Failed to ensure table exists: $e');
      throw Exception('Failed to create database table: $e');
    }
  }
  
  /// Insert form data into SQLite
  Future<void> _insertFormData(Map<String, dynamic> data) async {
    try {
      final db = await _dbHelper.database;
      
      // Check if record already exists
      final existingRecords = await db.query(
        'kendala_forms',
        where: 'no_spb = ?',
        whereArgs: [data['no_spb']],
        limit: 1,
      );
      
      if (existingRecords.isEmpty) {
        // Insert new record
        await db.insert('kendala_forms', data);
      } else {
        // Update existing record
        await db.update(
          'kendala_forms',
          data,
          where: 'no_spb = ?',
          whereArgs: [data['no_spb']],
        );
      }
    } catch (e) {
      AppLogger.error('Failed to insert form data: $e');
      throw Exception('Failed to insert form data: $e');
    }
  }
  
  /// Migrate pending forms list
  Future<void> _migratePendingFormsList(List<String> pendingForms) async {
    try {
      final db = await _dbHelper.database;
      
      // Update is_synced flag for pending forms
      for (final spbId in pendingForms) {
        await db.update(
          'kendala_forms',
          {'is_synced': 0},
          where: 'no_spb = ?',
          whereArgs: [spbId],
        );
      }
      
      AppLogger.info('Migrated ${pendingForms.length} pending forms');
    } catch (e) {
      AppLogger.error('Failed to migrate pending forms list: $e');
      throw Exception('Failed to migrate pending forms list: $e');
    }
  }
  
  /// Verify migration by comparing data in SharedPreferences and SQLite
  Future<bool> _verifyMigration(List<String> formDataKeys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final db = await _dbHelper.database;
      
      // Count forms in SQLite
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM kendala_forms');
      final dbCount = Sqflite.firstIntValue(countResult) ?? 0;
      
      // Basic count verification
      if (dbCount < formDataKeys.length) {
        AppLogger.warning('Verification failed: Expected ${formDataKeys.length} forms, found $dbCount in database');
        return false;
      }
      
      // Verify a sample of forms
      int verificationCount = 0;
      final sampleSize = formDataKeys.length > 10 ? 10 : formDataKeys.length;
      
      for (int i = 0; i < sampleSize; i++) {
        final key = formDataKeys[i];
        final spbId = key.replaceFirst('kendala_form_data_', '');
        
        // Get form data from SharedPreferences
        final formDataJson = prefs.getString(key);
        if (formDataJson == null) continue;
        
        // Get form data from SQLite
        final dbForms = await db.query(
          'kendala_forms',
          where: 'no_spb = ?',
          whereArgs: [spbId],
          limit: 1,
        );
        
        if (dbForms.isEmpty) {
          AppLogger.warning('Verification failed: Form $spbId not found in database');
          continue;
        }
        
        // Verify basic data
        final dbForm = dbForms.first;
        final prefData = jsonDecode(formDataJson) as Map<String, dynamic>;
        
        if (dbForm['no_spb'] == spbId && 
            dbForm['created_by'] == prefData['createdBy']) {
          verificationCount++;
        }
      }
      
      // Verification passes if at least 80% of sampled forms match
      final verificationRate = verificationCount / sampleSize;
      AppLogger.info('Verification rate: ${(verificationRate * 100).toStringAsFixed(2)}%');
      
      return verificationRate >= 0.8;
    } catch (e) {
      AppLogger.error('Verification failed with error: $e');
      return false;
    }
  }
  
  /// Clean up old SharedPreferences data after successful migration
  Future<void> cleanupSharedPreferences() async {
    try {
      migrationStatusNotifier.value = MigrationStatus.cleaning;
      
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // Filter keys related to Kendala forms
      final kendalaKeys = allKeys.where((key) => 
          key.startsWith('kendala_form_data_') || 
          key.startsWith('kendala_driver_changed_') ||
          key.startsWith('kendala_text_') ||
          key.startsWith('kendala_synced_') ||
          key.startsWith('kendala_modified_') ||
          key == 'pending_kendala_forms'
      ).toList();
      
      // Remove each key
      for (final key in kendalaKeys) {
        await prefs.remove(key);
      }
      
      AppLogger.info('Cleaned up ${kendalaKeys.length} SharedPreferences keys');
      migrationStatusNotifier.value = MigrationStatus.completed;
    } catch (e) {
      AppLogger.error('Failed to clean up SharedPreferences: $e');
      errorMessageNotifier.value = 'Failed to clean up old data: $e';
    }
  }
  
  /// Get migration statistics
  Future<MigrationStats> getMigrationStats() async {
    try {
      final db = await _dbHelper.database;
      
      // Count total forms
      final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM kendala_forms');
      final totalForms = Sqflite.firstIntValue(totalResult) ?? 0;
      
      // Count synced forms
      final syncedResult = await db.rawQuery('SELECT COUNT(*) as count FROM kendala_forms WHERE is_synced = 1');
      final syncedForms = Sqflite.firstIntValue(syncedResult) ?? 0;
      
      // Count pending forms
      final pendingForms = totalForms - syncedForms;
      
      return MigrationStats(
        totalForms: totalForms,
        syncedForms: syncedForms,
        pendingForms: pendingForms,
      );
    } catch (e) {
      AppLogger.error('Failed to get migration stats: $e');
      return MigrationStats(
        totalForms: 0,
        syncedForms: 0,
        pendingForms: 0,
      );
    }
  }
  
  /// Dispose resources
  void dispose() {
    migrationStatusNotifier.dispose();
    errorMessageNotifier.dispose();
    progressNotifier.dispose();
    totalItemsNotifier.dispose();
  }
}

/// Migration status enum
enum MigrationStatus { 
  notStarted, 
  inProgress, 
  completed, 
  failed, 
  cleaning 
}

/// Migration statistics class
class MigrationStats {
  final int totalForms;
  final int syncedForms;
  final int pendingForms;
  
  MigrationStats({
    required this.totalForms,
    required this.syncedForms,
    required this.pendingForms,
  });
}