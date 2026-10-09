import 'package:sqflite/sqflite.dart';

class SettingsDao {
  const SettingsDao(this._db);

  final Database _db;
  static const _table = 'app_settings';

  Future<String?> get(String key) async {
    final rows = await _db.query(_table, where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> set(String key, String value) => _db.insert(_table, {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> clear({Set<String> keep = const {}}) => keep.isEmpty
      ? _db.delete(_table)
      : _db.delete(
          _table,
          where: 'key NOT IN (${List.filled(keep.length, '?').join(',')})',
          whereArgs: keep.toList(),
        );
}
