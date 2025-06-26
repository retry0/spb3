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
        version: 6, // Increased version for auth_sync_queue table
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

      // Data entries table for main application data
      await db.execute('''
        CREATE TABLE data_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          remote_id TEXT UNIQUE,
          UserName TEXT NOT NULL,
          Nama TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'active',
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          synced_at INTEGER,
          is_dirty INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Activity logs table
      await db.execute('''
        CREATE TABLE activity_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          description TEXT NOT NULL,
          user_id TEXT,
          username TEXT,
          metadata TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
          FOREIGN KEY (username) REFERENCES users (UserName) ON DELETE SET NULL
        )
      ''');

      // Sync queue table for offline operations
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation TEXT NOT NULL,
          table_name TEXT NOT NULL,
          record_id TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          priority INTEGER NOT NULL DEFAULT 5,
          status TEXT NOT NULL DEFAULT 'pending'
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
          jum_jjg TEXT NOT NULL,
          brondolan TEXT NOT NULL,
          tot_berat_taksasi TEXT NOT NULL,
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

      // Auth sync queue table for offline authentication operations
      await db.execute('''
        CREATE TABLE auth_sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation TEXT NOT NULL,
          data TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
      ''');

      // Create indexes for better performance
      await db.execute('CREATE INDEX idx_settings_key ON settings (key)');
      await db.execute('CREATE INDEX idx_users_username ON users (UserName)');
      await db.execute('CREATE INDEX idx_users_is_dirty ON users (is_dirty)');
      await db.execute('CREATE INDEX idx_users_synced_at ON users (synced_at)');
      await db.execute(
        'CREATE INDEX idx_data_entries_status ON data_entries (status)',
      );
      await db.execute(
        'CREATE INDEX idx_data_entries_synced ON data_entries (synced_at)',
      );
      await db.execute(
        'CREATE INDEX idx_activity_logs_type ON activity_logs (type)',
      );
      await db.execute(
        'CREATE INDEX idx_activity_logs_username ON activity_logs (username)',
      );
      await db.execute(
        'CREATE INDEX idx_activity_logs_created ON activity_logs (created_at)',
      );
      await db.execute(
        'CREATE INDEX idx_sync_queue_operation ON sync_queue (operation)',
      );
      await db.execute(
        'CREATE INDEX idx_sync_queue_status ON sync_queue (status)',
      );
      await db.execute(
        'CREATE INDEX idx_sync_queue_priority ON sync_queue (priority)',
      );
      await db.execute('CREATE INDEX idx_spb_data_driver ON spb_data (driver)');
      await db.execute(
        'CREATE INDEX idx_spb_data_kd_vendor ON spb_data (kode_vendor)',
      );
      await db.execute('CREATE INDEX idx_spb_data_status ON spb_data (status)');
      await db.execute(
        'CREATE INDEX idx_spb_data_is_synced ON spb_data (is_synced)',
      );
      await db.execute(
        'CREATE INDEX idx_auth_tokens_user_id ON auth_tokens (user_id)',
      );
      await db.execute(
        'CREATE INDEX idx_auth_tokens_username ON auth_tokens (username)',
      );
      await db.execute(
        'CREATE INDEX idx_auth_tokens_expires_at ON auth_tokens (expires_at)',
      );
      await db.execute(
        'CREATE INDEX idx_auth_sync_queue_status ON auth_sync_queue (status)',
      );
      await db.execute(
        'CREATE INDEX idx_auth_sync_queue_operation ON auth_sync_queue (operation)',
      );

      AppLogger.info('Database tables created successfully');
    } catch (e) {
      AppLogger.error('Failed to create database tables', e);
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info(
      'Upgrading database from version $oldVersion to $newVersion',
    );

    if (oldVersion < 2) {
      // Migration to add username support
      await _migrateToUsernameAuth(db);
    }

    if (oldVersion < 4) {
      // Migration to add user profile sync fields
      await _migrateToAddUserSyncFields(db);

      // Migration to add SPB data table
      await _migrateToAddSpbDataTable(db);
    }

    if (oldVersion < 5) {
      // Migration to add auth tokens and user credentials tables
      await _migrateToAddOfflineAuthTables(db);
    }

    if (oldVersion < 6) {
      // Migration to add auth sync queue table
      await _migrateToAddAuthSyncQueueTable(db);
    }
  }

  Future<void> _migrateToUsernameAuth(Database db) async {
    try {
      AppLogger.info('Migrating to username-based authentication...');

      // Add username column to users table
      await db.execute('ALTER TABLE users ADD COLUMN username TEXT');

      // Add username column to activity_logs
      await db.execute('ALTER TABLE activity_logs ADD COLUMN username TEXT');

      // Create new indexes
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_username ON users (username)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_logs_username ON activity_logs (username)',
      );

      // Generate usernames for existing users (email prefix)
      final existingUsers = await db.query('users');
      for (final user in existingUsers) {
        if (user['username'] == null && user['email'] != null) {
          final email = user['email'] as String;
          final username = email.split('@')[0];
          await db.update(
            'users',
            {'username': username},
            where: 'id = ?',
            whereArgs: [user['id']],
          );
        }
      }

      // Make username unique and not null
      await db.execute(
        'CREATE UNIQUE INDEX idx_users_username_unique ON users (username)',
      );

      AppLogger.info('Username authentication migration completed');
    } catch (e) {
      AppLogger.error('Failed to migrate to username authentication', e);
      rethrow;
    }
  }

  Future<void> _migrateToAddUserSyncFields(Database db) async {
    try {
      AppLogger.info('Migrating to add user profile sync fields...');

      // Check if the columns already exist
      final userTableInfo = await db.rawQuery('PRAGMA table_info(users)');
      final columnNames =
          userTableInfo.map((col) => col['name'] as String).toList();

      // Add sync status column if it doesn't exist
      if (!columnNames.contains('last_sync_status')) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN last_sync_status TEXT DEFAULT "success"',
        );
      }

      // Add sync error column if it doesn't exist
      if (!columnNames.contains('sync_error')) {
        await db.execute('ALTER TABLE users ADD COLUMN sync_error TEXT');
      }

      // Add is_dirty column if it doesn't exist
      if (!columnNames.contains('is_dirty')) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN is_dirty BOOLEAN NOT NULL DEFAULT 0',
        );
      }

      // Add local_updated_at column if it doesn't exist
      if (!columnNames.contains('local_updated_at')) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN local_updated_at INTEGER',
        );
      }

      // Create index for is_dirty if it doesn't exist
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='users'",
      );
      final indexNames = indexes.map((idx) => idx['name'] as String).toList();

      if (!indexNames.contains('idx_users_is_dirty')) {
        await db.execute('CREATE INDEX idx_users_is_dirty ON users (is_dirty)');
      }

      AppLogger.info('User profile sync fields migration completed');
    } catch (e) {
      AppLogger.error('Failed to migrate user profile sync fields', e);
      rethrow;
    }
  }

  Future<void> _migrateToAddSpbDataTable(Database db) async {
    try {
      AppLogger.info('Migrating to add SPB data table...');

      // Check if spb_data table already exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='spb_data'",
      );

      if (tables.isEmpty) {
        // Create SPB data table
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
          jum_jjg TEXT NOT NULL,
          brondolan TEXT NOT NULL,
          tot_berat_taksasi TEXT NOT NULL,
           driverName TEXT NULL,
            millTujuanName TEXT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            is_synced INTEGER NOT NULL DEFAULT 1
          )
        ''');

        // Create indexes
        await db.execute(
          'CREATE INDEX idx_spb_data_driver ON spb_data (driver)',
        );
        await db.execute(
          'CREATE INDEX idx_spb_data_kd_vendor ON spb_data (kode_vendor)',
        );
        await db.execute(
          'CREATE INDEX idx_spb_data_status ON spb_data (status)',
        );
        await db.execute(
          'CREATE INDEX idx_spb_data_is_synced ON spb_data (is_synced)',
        );

        AppLogger.info('SPB data table created successfully');
      } else {
        AppLogger.info('SPB data table already exists, skipping migration');
      }
    } catch (e) {
      AppLogger.error('Failed to migrate to add SPB data table', e);
      rethrow;
    }
  }

  Future<void> _migrateToAddOfflineAuthTables(Database db) async {
    try {
      AppLogger.info('Migrating to add offline authentication tables...');

      // Check if auth_tokens table already exists
      final authTokensTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='auth_tokens'",
      );

      if (authTokensTables.isEmpty) {
        // Create auth_tokens table
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

        // Create indexes for auth_tokens
        await db.execute(
          'CREATE INDEX idx_auth_tokens_user_id ON auth_tokens (user_id)',
        );
        await db.execute(
          'CREATE INDEX idx_auth_tokens_username ON auth_tokens (username)',
        );
        await db.execute(
          'CREATE INDEX idx_auth_tokens_expires_at ON auth_tokens (expires_at)',
        );
      }

      // Check if user_credentials table already exists
      final userCredentialsTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='user_credentials'",
      );

      if (userCredentialsTables.isEmpty) {
        // Create user_credentials table
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
      }

      AppLogger.info('Offline authentication tables created successfully');
    } catch (e) {
      AppLogger.error(
        'Failed to migrate to add offline authentication tables',
        e,
      );
      rethrow;
    }
  }

  Future<void> _migrateToAddAuthSyncQueueTable(Database db) async {
    try {
      AppLogger.info('Migrating to add auth sync queue table...');

      // Check if auth_sync_queue table already exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='auth_sync_queue'",
      );

      if (tables.isEmpty) {
        // Create auth_sync_queue table
        await db.execute('''
          CREATE TABLE auth_sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation TEXT NOT NULL,
            data TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');

        // Create indexes
        await db.execute(
          'CREATE INDEX idx_auth_sync_queue_status ON auth_sync_queue (status)',
        );
        await db.execute(
          'CREATE INDEX idx_auth_sync_queue_operation ON auth_sync_queue (operation)',
        );

        AppLogger.info('Auth sync queue table created successfully');
      } else {
        AppLogger.info(
          'Auth sync queue table already exists, skipping migration',
        );
      }
    } catch (e) {
      AppLogger.error('Failed to migrate to add auth sync queue table', e);
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
      await txn.delete('data_entries');
      await txn.delete('activity_logs');
      await txn.delete('sync_queue');
      await txn.delete('spb_data');
      await txn.delete('auth_tokens');
      await txn.delete('user_credentials');
      await txn.delete('auth_sync_queue');
    });
    AppLogger.info('All database data cleared');
  }

  // Auth token operations
  Future<void> saveAuthToken(
    String userId,
    String username,
    String token, {
    int? expiresAt,
  }) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Delete any existing tokens for this user
      await db.delete(
        'auth_tokens',
        where: 'username = ?',
        whereArgs: [username],
      );

      // Insert new token
      await db.insert('auth_tokens', {
        'user_id': userId,
        'username': username,
        'token': token,
        'created_at': now,
        'expires_at': expiresAt,
        'last_used_at': now,
      });

      AppLogger.info('Auth token saved for user: $username');
    } catch (e) {
      AppLogger.error('Failed to save auth token', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getLatestAuthToken(String username) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Get the latest non-expired token
      final results = await db.query(
        'auth_tokens',
        where: 'username = ? AND (expires_at IS NULL OR expires_at > ?)',
        whereArgs: [username, now],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (results.isNotEmpty) {
        // Update last used timestamp
        await db.update(
          'auth_tokens',
          {'last_used_at': now},
          where: 'id = ?',
          whereArgs: [results.first['id']],
        );

        return results.first;
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed to get auth token', e);
      return null;
    }
  }

  // User credentials operations
  Future<void> saveUserCredentials(
    String username,
    String passwordHash,
    String salt,
  ) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Check if credentials already exist
      final existing = await db.query(
        'user_credentials',
        where: 'username = ?',
        whereArgs: [username],
      );

      if (existing.isEmpty) {
        // Insert new credentials
        await db.insert('user_credentials', {
          'username': username,
          'password_hash': passwordHash,
          'salt': salt,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        // Update existing credentials
        await db.update(
          'user_credentials',
          {'password_hash': passwordHash, 'salt': salt, 'updated_at': now},
          where: 'username = ?',
          whereArgs: [username],
        );
      }

      AppLogger.info('User credentials saved for: $username');
    } catch (e) {
      AppLogger.error('Failed to save user credentials', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserCredentials(String username) async {
    final db = await database;
    try {
      final results = await db.query(
        'user_credentials',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      AppLogger.error('Failed to get user credentials', e);
      return null;
    }
  }

  Future<void> updateLastOnlineAuth(String username) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db.update(
        'user_credentials',
        {'last_online_auth': now},
        where: 'username = ?',
        whereArgs: [username],
      );

      AppLogger.info('Updated last online auth timestamp for: $username');
    } catch (e) {
      AppLogger.error('Failed to update last online auth timestamp', e);
      rethrow;
    }
  }

  // Clean up expired tokens
  Future<void> cleanupExpiredTokens() async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final deleted = await db.delete(
        'auth_tokens',
        where: 'expires_at IS NOT NULL AND expires_at < ?',
        whereArgs: [now],
      );

      if (deleted > 0) {
        AppLogger.info('Cleaned up $deleted expired auth tokens');
      }
    } catch (e) {
      AppLogger.error('Failed to clean up expired tokens', e);
      // Don't rethrow - this is a background operation
    }
  }

  // Auth sync queue operations
  Future<int> addToAuthSyncQueue(
    String operation,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      return await db.insert('auth_sync_queue', {
        'operation': operation,
        'data': jsonEncode(data),
        'status': 'pending',
        'retry_count': 0,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      AppLogger.error('Failed to add to auth sync queue', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingAuthSyncItems() async {
    final db = await database;
    try {
      return await db.query(
        'auth_sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      AppLogger.error('Failed to get pending auth sync items', e);
      return [];
    }
  }

  Future<int> updateAuthSyncItem(int id, Map<String, dynamic> data) async {
    final db = await database;
    try {
      data['updated_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return await db.update(
        'auth_sync_queue',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      AppLogger.error('Failed to update auth sync item', e);
      rethrow;
    }
  }

  Future<int> removeAuthSyncItem(int id) async {
    final db = await database;
    try {
      return await db.delete(
        'auth_sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      AppLogger.error('Failed to remove auth sync item', e);
      rethrow;
    }
  }
}
