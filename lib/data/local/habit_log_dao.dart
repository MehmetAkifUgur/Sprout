import 'package:sqflite/sqflite.dart';

import '../../domain/date_utils.dart';
import '../models/habit_log.dart';

class HabitLogDao {
  const HabitLogDao(this._db);

  final Database _db;
  static const _table = 'habit_logs';

  /// Aynı alışkanlık + gün için tek kayıt tutulur; varsa üzerine yazılır.
  Future<void> upsert(HabitLog log) => _db.insert(
    _table,
    log.toMap()..remove('id'),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<List<HabitLog>> getForHabit(int habitId) async {
    final rows = await _db.query(
      _table,
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'date ASC',
    );
    return rows.map(HabitLog.fromMap).toList();
  }

  Future<List<HabitLog>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'date ASC');
    return rows.map(HabitLog.fromMap).toList();
  }

  Future<HabitLog?> get(int habitId, DateTime date) async {
    final rows = await _db.query(
      _table,
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, dayKey(date)],
    );
    return rows.isEmpty ? null : HabitLog.fromMap(rows.first);
  }

  Future<int> deleteForHabit(int habitId) =>
      _db.delete(_table, where: 'habit_id = ?', whereArgs: [habitId]);
}
