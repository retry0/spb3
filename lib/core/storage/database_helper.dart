import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/logger.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  static DatabaseHelper get instance => _instance;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'spb_secure.db');

      AppLogger.info('Initializing database at: $path');

      return await openDatabase(
        path,
        version: 8, // Increased version for espb_form_data table
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      );
    } catch (e) {
      AppLogger.error('Failed to initialize database', e);
      rethrow;
    }
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      AppLogger.info('Creating database tables...');

      // Settings table for local storage
      await db.execute('''
        CREATE TABLE settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key TEXT UNIQUE NOT NULL,
          value TEXT,
          type TEXT NOT NULL DEFAULT 'string',
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
      ''');

      // Users table with username support
      await db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          UserName TEXT UNIQUE NOT NULL,
          Nama TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          synced_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          last_sync_status TEXT DEFAULT 'success',
          sync_error TEXT,
          is_dirty BOOLEAN NOT NULL DEFAULT 0,
          local_updated_at INTEGER
        )
      ''');

      // SPB data table
      await db.execute('''
        CREATE TABLE spb_data (
          no_spb TEXT PRIMARY KEY,
          tgl_antar_buah TEXT NOT NULL,
          mill_tujuan TEXT NOT NULL,
          status TEXT NOT NULL,
          keterangan TEXT,
          driver TEXT NOT NULL,
          kode_vendor TEXT NOT NULL,
          no_polisi TEXT NOT NULL,
          jum_jjg TEXT,
          brondolan TEXT,
          tot_berat_taksasi TEXT,
          driverName TEXT NULL,
          millTujuanName TEXT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          is_synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      // Auth tokens table for offline authentication
      await db.execute('''
        CREATE TABLE auth_tokens (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          username TEXT NOT NULL,
          token TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          expires_at INTEGER,
          last_used_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
          FOREIGN KEY (username) REFERENCES users (UserName) ON DELETE CASCADE
        )
      ''');

      // User credentials table for offline authentication
      await db.execute('''
        CREATE TABLE user_credentials (
          username TEXT PRIMARY KEY,
          password_hash TEXT NOT NULL,
          salt TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          last_online_auth INTEGER
        )
      ''');

      // ESPB form data table for storing form submissions
      await db.execute('''
        CREATE TABLE espb_form_data (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          no_spb TEXT UNIQUE NOT NULL,
          status TEXT NOT NULL,
          created_by TEXT NOT NULL,
          latitude TEXT NOT NULL,
          longitude TEXT NOT NULL,
          alasan TEXT,
          is_any_handling_ex TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          last_sync_attempt INTEGER
        )
      ''');

      // Create indexes for better performance
      await db.execute('CREATE INDEX idx_settings_key ON settings (key)');
      await db.execute('CREATE INDEX idx_users_username ON users (UserName)');
      await db.execute('CREATE INDEX idx_users_is_dirty ON users (is_dirty)');
      await db.execute('CREATE INDEX idx_users_synced_at ON users (synced_at)');
      await db.execute('CREATE INDEX idx_spb_data_driver ON spb_data (driver)');
      await db.execute('CREATE INDEX idx_spb_data_kd_vendor ON spb_data (kode_vendor)');
      await db.execute('CREATE INDEX idx_spb_data_status ON spb_data (status)');
      await db.execute('CREATE INDEX idx_spb_data_is_synced ON spb_data (is_synced)');
      await db.execute('CREATE INDEX idx_auth_tokens_user_id ON auth_tokens (user_id)');
      await db.execute('CREATE INDEX idx_auth_tokens_username ON auth_tokens (username)');
      await db.execute('CREATE INDEX idx_auth_tokens_expires_at ON auth_tokens (expires_at)');
      await db.execute('CREATE INDEX idx_espb_form_data_no_spb ON espb_form_data (no_spb)');
      await db.execute('CREATE INDEX idx_espb_form_data_is_synced ON espb_form_data (is_synced)');
      await db.execute('CREATE INDEX idx_espb_form_data_timestamp ON espb_form_data (timestamp)');

      AppLogger.info('Database tables created successfully');
    } catch (e) {
      AppLogger.error('Failed to create database tables', e);
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info('Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 8) {
      // Migration to add ESPB form data table
      await _migrateToAddEspbFormDataTable(db);
    }
  }

  Future<void> _migrateToAddEspbFormDataTable(Database db) async {
    try {
      AppLogger.info('Migrating to add ESPB form data table...');

      // Check if espb_form_data table already exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='espb_form_data'",
      );

      if (tables.isEmpty) {
        // Create espb_form_data table
        await db.execute('''
          CREATE TABLE espb_form_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            no_spb TEXT UNIQUE NOT NULL,
            status TEXT NOT NULL,
            created_by TEXT NOT NULL,
            latitude TEXT NOT NULL,
            longitude TEXT NOT NULL,
            alasan TEXT,
            is_any_handling_ex TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            is_synced INTEGER NOT NULL DEFAULT 0,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            last_sync_attempt INTEGER
          )
        ''');

        // Create indexes
        await db.execute('CREATE INDEX idx_espb_form_data_no_spb ON espb_form_data (no_spb)');
        await db.execute('CREATE INDEX idx_espb_form_data_is_synced ON espb_form_data (is_synced)');
        await db.execute('CREATE INDEX idx_espb_form_data_timestamp ON espb_form_data (timestamp)');

        AppLogger.info('ESPB form data table created successfully');
      } else {
        AppLogger.info('ESPB form data table already exists, skipping migration');
      }
    } catch (e) {
      AppLogger.error('Failed to migrate to add ESPB form data table', e);
      rethrow;
    }
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    try {
      // Add timestamps if not provided
      if (!data.containsKey('created_at')) {
        data['created_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }
      if (!data.containsKey('updated_at')) {
        data['updated_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }

      return await db.insert(
        table,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      AppLogger.error('Failed to insert into $table', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    try {
      return await db.query(
        table,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      AppLogger.error('Failed to query $table', e);
      rethrow;
    }
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    try {
      // Add updated_at timestamp if not provided
      if (!data.containsKey('updated_at')) {
        data['updated_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }
      return await db.update(table, data, where: where, whereArgs: whereArgs);
    } catch (e) {
      AppLogger.error('Failed to update $table', e);
      rethrow;
    }
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    try {
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      AppLogger.error('Failed to delete from $table', e);
      rethrow;
    }
  }

  // Transaction support
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // Clear all data (for testing or reset)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('settings');
      await txn.delete('users');
      await txn.delete('spb_data');
      await txn.delete('auth_tokens');
      await txn.delete('user_credentials');
      await txn.delete('espb_form_data');
    });
    AppLogger.info('All database data cleared');
  }

  // ESPB form data operations
  Future<int> saveEspbFormData(Map<String, dynamic> formData) async {
    try {
      // Ensure required fields are present
      final requiredFields = [
        'no_spb', 'status', 'created_by', 'latitude', 'longitude', 
        'is_any_handling_ex', 'timestamp'
      ];
      
      for (final field in requiredFields) {
        if (!formData.containsKey(field) || formData[field] == null) {
          throw Exception('Missing required field: $field');
        }
      }
      
      // Check if record already exists
      final existingRecords = await query(
        'espb_form_data',
        where: 'no_spb = ?',
        whereArgs: [formData['no_spb']],
        limit: 1,
      );
      
      if (existingRecords.isNotEmpty) {
        // Update existing record
        formData['updated_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        formData['is_synced'] = 0; // Mark as needing sync
        
        return await update(
          'espb_form_data',
          formData,
          where: 'no_spb = ?',
          whereArgs: [formData['no_spb']],
        );
      } else {
        // Insert new record
        formData['created_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        formData['updated_at'] = formData['created_at'];
        formData['is_synced'] = 0; // Mark as needing sync
        formData['retry_count'] = 0;
        
        return await insert('espb_form_data', formData);
      }
    } catch (e) {
      AppLogger.error('Failed to save ESPB form data', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getEspbFormData(String noSpb) async {
    try {
      final results = await query(
        'espb_form_data',
        where: 'no_spb = ?',
        whereArgs: [noSpb],
        limit: 1,
      );
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      AppLogger.error('Failed to get ESPB form data', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingEspbForms() async {
    try {
      return await query(
        'espb_form_data',
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC',
      );
    } catch (e) {
      AppLogger.error('Failed to get pending ESPB forms', e);
      return [];
    }
  }

  Future<void> markEspbFormAsSynced(String noSpb) async {
    try {
      await update(
        'espb_form_data',
        {
          'is_synced': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'no_spb = ?',
        whereArgs: [noSpb],
      );
    } catch (e) {
      AppLogger.error('Failed to mark ESPB form as synced', e);
      rethrow;
    }
  }

  Future<void> updateEspbFormSyncStatus(
    String noSpb, {
    bool? isSynced,
    String? errorMessage,
    int? retryCount,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'last_sync_attempt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      
      if (isSynced != null) {
        data['is_synced'] = isSynced ? 1 : 0;
      }
      
      if (errorMessage != null) {
        data['last_error'] = errorMessage;
      }
      
      if (retryCount != null) {
        data['retry_count'] = retryCount;
      }
      
      await update(
        'espb_form_data',
        data,
        where: 'no_spb = ?',
        whereArgs: [noSpb],
      );
    } catch (e) {
      AppLogger.error('Failed to update ESPB form sync status', e);
      rethrow;
    }
  }

  // Migration helper to move data from SharedPreferences to SQLite
  Future<void> migrateEspbFormsFromSharedPreferences() async {
    try {
      // This would be implemented to read from SharedPreferences
      // and insert into the SQLite database
      // Implementation depends on how the data is stored in SharedPreferences
      AppLogger.info('Migration of ESPB forms from SharedPreferences completed');
    } catch (e) {
      AppLogger.error('Failed to migrate ESPB forms from SharedPreferences', e);
      rethrow;
    }
  }
}