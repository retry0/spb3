import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';
import '../utils/logger.dart';

abstract class LocalStorage {
  Future<void> setString(String key, String value);
  Future<String?> getString(String key);
  Future<void> setBool(String key, bool value);
  Future<bool?> getBool(String key);
  Future<void> setInt(String key, int value);
  Future<int?> getInt(String key);
  Future<void> setDouble(String key, double value);
  Future<double?> getDouble(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<List<String>?> getStringList(String key);
  Future<void> remove(String key);
  Future<void> clear();
}

class LocalStorageImpl implements LocalStorage {
  final SharedPreferences _prefs;
  final DatabaseHelper _dbHelper;

  const LocalStorageImpl(this._prefs, this._dbHelper);

  @override
  Future<void> setString(String key, String value) async {
    try {
      // Store in both SharedPreferences (for quick access) and SQLite (for persistence)
      await _prefs.setString(key, value);
      // await _dbHelper.insert('settings', {
      //   'key': key,
      //   'value': value,
      //   'type': 'string',
      // });
    } catch (e) {
      AppLogger.error('Failed to set string for key: $key', e);
      // Fallback to SharedPreferences only
      await _prefs.setString(key, value);
    }
  }

  @override
  Future<String?> getString(String key) async {
    try {
      // Try SharedPreferences first for speed
      String? value = _prefs.getString(key);

      if (value == null) {
        // Fallback to SQLite
        final results = await _dbHelper.query(
          'settings',
          where: 'key = ? AND type = ?',
          whereArgs: [key, 'string'],
          limit: 1,
        );

        if (results.isNotEmpty) {
          value = results.first['value'] as String?;
          // Cache in SharedPreferences for next time
          if (value != null) {
            await _prefs.setString(key, value);
          }
        }
      }

      return value;
    } catch (e) {
      AppLogger.error('Failed to get string for key: $key', e);
      return _prefs.getString(key);
    }
  }

  @override
  Future<void> setBool(String key, bool value) async {
    try {
      await _prefs.setBool(key, value);
      await _dbHelper.insert('settings', {
        'key': key,
        'value': value.toString(),
        'type': 'bool',
      });
    } catch (e) {
      AppLogger.error('Failed to set bool for key: $key', e);
      await _prefs.setBool(key, value);
    }
  }

  @override
  Future<bool?> getBool(String key) async {
    try {
      bool? value = _prefs.getBool(key);

      if (value == null) {
        final results = await _dbHelper.query(
          'settings',
          where: 'key = ? AND type = ?',
          whereArgs: [key, 'bool'],
          limit: 1,
        );

        if (results.isNotEmpty) {
          final stringValue = results.first['value'] as String?;
          if (stringValue != null) {
            value = stringValue.toLowerCase() == 'true';
            await _prefs.setBool(key, value);
          }
        }
      }

      return value;
    } catch (e) {
      AppLogger.error('Failed to get bool for key: $key', e);
      return _prefs.getBool(key);
    }
  }

  @override
  Future<void> setInt(String key, int value) async {
    try {
      await _prefs.setInt(key, value);
      await _dbHelper.insert('settings', {
        'key': key,
        'value': value.toString(),
        'type': 'int',
      });
    } catch (e) {
      AppLogger.error('Failed to set int for key: $key', e);
      await _prefs.setInt(key, value);
    }
  }

  @override
  Future<int?> getInt(String key) async {
    try {
      int? value = _prefs.getInt(key);

      if (value == null) {
        final results = await _dbHelper.query(
          'settings',
          where: 'key = ? AND type = ?',
          whereArgs: [key, 'int'],
          limit: 1,
        );

        if (results.isNotEmpty) {
          final stringValue = results.first['value'] as String?;
          if (stringValue != null) {
            value = int.tryParse(stringValue);
            if (value != null) {
              await _prefs.setInt(key, value);
            }
          }
        }
      }

      return value;
    } catch (e) {
      AppLogger.error('Failed to get int for key: $key', e);
      return _prefs.getInt(key);
    }
  }

  @override
  Future<void> setDouble(String key, double value) async {
    try {
      await _prefs.setDouble(key, value);
      await _dbHelper.insert('settings', {
        'key': key,
        'value': value.toString(),
        'type': 'double',
      });
    } catch (e) {
      AppLogger.error('Failed to set double for key: $key', e);
      await _prefs.setDouble(key, value);
    }
  }

  @override
  Future<double?> getDouble(String key) async {
    try {
      double? value = _prefs.getDouble(key);

      if (value == null) {
        final results = await _dbHelper.query(
          'settings',
          where: 'key = ? AND type = ?',
          whereArgs: [key, 'double'],
          limit: 1,
        );

        if (results.isNotEmpty) {
          final stringValue = results.first['value'] as String?;
          if (stringValue != null) {
            value = double.tryParse(stringValue);
            if (value != null) {
              await _prefs.setDouble(key, value);
            }
          }
        }
      }

      return value;
    } catch (e) {
      AppLogger.error('Failed to get double for key: $key', e);
      return _prefs.getDouble(key);
    }
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    try {
      await _prefs.setStringList(key, value);
      await _dbHelper.insert('settings', {
        'key': key,
        'value': value.join('|'), // Simple delimiter-based storage
        'type': 'string_list',
      });
    } catch (e) {
      AppLogger.error('Failed to set string list for key: $key', e);
      await _prefs.setStringList(key, value);
    }
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    try {
      List<String>? value = _prefs.getStringList(key);

      if (value == null) {
        final results = await _dbHelper.query(
          'settings',
          where: 'key = ? AND type = ?',
          whereArgs: [key, 'string_list'],
          limit: 1,
        );

        if (results.isNotEmpty) {
          final stringValue = results.first['value'] as String?;
          if (stringValue != null && stringValue.isNotEmpty) {
            value = stringValue.split('|');
            await _prefs.setStringList(key, value);
          }
        }
      }

      return value;
    } catch (e) {
      AppLogger.error('Failed to get string list for key: $key', e);
      return _prefs.getStringList(key);
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      await _prefs.remove(key);
      await _dbHelper.delete('settings', where: 'key = ?', whereArgs: [key]);
    } catch (e) {
      AppLogger.error('Failed to remove key: $key', e);
      await _prefs.remove(key);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _prefs.clear();
      await _dbHelper.delete('settings');
    } catch (e) {
      AppLogger.error('Failed to clear storage', e);
      await _prefs.clear();
    }
  }
}
