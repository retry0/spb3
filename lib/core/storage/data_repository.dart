import 'dart:convert';

import 'database_helper.dart';
import '../utils/logger.dart';

class DataRepository {
  final DatabaseHelper _dbHelper;

  DataRepository(this._dbHelper);

  // User data operations
  Future<void> saveUser(Map<String, dynamic> userData) async {
    try {
      await _dbHelper.insert('users', {
        'id': userData['id'],
        'email': userData['email'],
        'name': userData['name'],
        'avatar': userData['avatar'],
        'created_at': userData['created_at'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'updated_at': userData['updated_at'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (e) {
      AppLogger.error('Failed to save user data', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final results = await _dbHelper.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      AppLogger.error('Failed to get user data', e);
      return null;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _dbHelper.delete('users', where: 'id = ?', whereArgs: [userId]);
    } catch (e) {
      AppLogger.error('Failed to delete user data', e);
      rethrow;
    }
  }

  // Data entries operations
  Future<int> saveDataEntry(Map<String, dynamic> entryData) async {
    try {
      return await _dbHelper.insert('data_entries', {
        'remote_id': entryData['remote_id'],
        'name': entryData['name'],
        'email': entryData['email'],
        'status': entryData['status'] ?? 'active',
        'is_dirty': entryData['is_dirty'] ?? 0,
      });
    } catch (e) {
      AppLogger.error('Failed to save data entry', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDataEntries({
    String? status,
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    try {
      String? where;
      List<dynamic>? whereArgs;
      
      if (status != null) {
        where = 'status = ?';
        whereArgs = [status];
      }
      
      return await _dbHelper.query(
        'data_entries',
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy ?? 'created_at DESC',
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      AppLogger.error('Failed to get data entries', e);
      return [];
    }
  }

  Future<void> updateDataEntry(int id, Map<String, dynamic> updates) async {
    try {
      updates['is_dirty'] = 1; // Mark as dirty for sync
      await _dbHelper.update(
        'data_entries',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      AppLogger.error('Failed to update data entry', e);
      rethrow;
    }
  }

  Future<void> deleteDataEntry(int id) async {
    try {
      await _dbHelper.delete('data_entries', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      AppLogger.error('Failed to delete data entry', e);
      rethrow;
    }
  }

  // Activity logs operations
  Future<void> logActivity({
    required String type,
    required String description,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _dbHelper.insert('activity_logs', {
        'type': type,
        'description': description,
        'user_id': userId,
        'metadata': metadata != null ? jsonEncode(metadata) : null,
      });
    } catch (e) {
      AppLogger.error('Failed to log activity', e);
      // Don't rethrow for logging failures
    }
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? type,
    String? userId,
    int? limit,
    int? offset,
  }) async {
    try {
      String? where;
      List<dynamic>? whereArgs;
      
      if (type != null && userId != null) {
        where = 'type = ? AND user_id = ?';
        whereArgs = [type, userId];
      } else if (type != null) {
        where = 'type = ?';
        whereArgs = [type];
      } else if (userId != null) {
        where = 'user_id = ?';
        whereArgs = [userId];
      }
      
      final results = await _dbHelper.query(
        'activity_logs',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
        limit: limit ?? 50,
        offset: offset,
      );
      
      // Parse metadata JSON
      return results.map((row) {
        final Map<String, dynamic> activity = Map.from(row);
        if (activity['metadata'] != null) {
          try {
            activity['metadata'] = jsonDecode(activity['metadata']);
          } catch (e) {
            AppLogger.warning('Failed to parse activity metadata: ${activity['metadata']}');
            activity['metadata'] = null;
          }
        }
        return activity;
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get activity logs', e);
      return [];
    }
  }

  // Sync queue operations
  Future<void> addToSyncQueue({
    required String operation,
    required String tableName,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _dbHelper.insert('sync_queue', {
        'operation': operation,
        'table_name': tableName,
        'record_id': recordId,
        'data': jsonEncode(data),
      });
    } catch (e) {
      AppLogger.error('Failed to add to sync queue', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems({int? limit}) async {
    try {
      final results = await _dbHelper.query(
        'sync_queue',
        orderBy: 'created_at ASC',
        limit: limit ?? 100,
      );
      
      return results.map((row) {
        final Map<String, dynamic> item = Map.from(row);
        try {
          item['data'] = jsonDecode(item['data']);
        } catch (e) {
          AppLogger.warning('Failed to parse sync queue data: ${item['data']}');
          item['data'] = {};
        }
        return item;
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get pending sync items', e);
      return [];
    }
  }

  Future<void> removeSyncItem(int id) async {
    try {
      await _dbHelper.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      AppLogger.error('Failed to remove sync item', e);
      rethrow;
    }
  }

  Future<void> updateSyncItemError(int id, String error) async {
    try {
      await _dbHelper.update(
        'sync_queue',
        {
          'last_error': error,
          'retry_count': 'retry_count + 1',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      AppLogger.error('Failed to update sync item error', e);
      rethrow;
    }
  }

  // Search operations
  Future<List<Map<String, dynamic>>> searchDataEntries(String query) async {
    try {
      return await _dbHelper.query(
        'data_entries',
        where: 'name LIKE ? OR email LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name ASC',
      );
    } catch (e) {
      AppLogger.error('Failed to search data entries', e);
      return [];
    }
  }

  // Statistics operations
  Future<Map<String, int>> getDataStatistics() async {
    try {
      final db = await _dbHelper.database;
      
      final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM data_entries');
      final activeResult = await db.rawQuery('SELECT COUNT(*) as count FROM data_entries WHERE status = ?', ['active']);
      final pendingResult = await db.rawQuery('SELECT COUNT(*) as count FROM data_entries WHERE status = ?', ['pending']);
      final dirtyResult = await db.rawQuery('SELECT COUNT(*) as count FROM data_entries WHERE is_dirty = 1');
      
      return {
        'total': totalResult.first['count'] as int,
        'active': activeResult.first['count'] as int,
        'pending': pendingResult.first['count'] as int,
        'dirty': dirtyResult.first['count'] as int,
      };
    } catch (e) {
      AppLogger.error('Failed to get data statistics', e);
      return {
        'total': 0,
        'active': 0,
        'pending': 0,
        'dirty': 0,
      };
    }
  }
}