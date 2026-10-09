import 'package:sqflite/sqflite.dart';

import '../../domain/date_utils.dart';
import '../../domain/habit_schedule.dart';

class PauseDao {
  const PauseDao(this._db);

  final DatabaseExecutor _db;
  static const _table = 'habit_pauses';

  /// habitId -> tatil aralıkları (başlangıca göre sıralı).
  Future<Map<int, List<PauseRange>>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'start_date ASC');
    final result = <int, List<PauseRange>>{};
    for (final r in rows) {
      result.putIfAbsent(r['habit_id'] as int, () => []).add(_fromRow(r));
    }
    return result;
  }

  Future<List<PauseRange>> getForHabit(int habitId) async {
    final rows = await _db.query(
      _table,
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'start_date ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> insert(int habitId, PauseRange pause) => _db.insert(_table, {
    'habit_id': habitId,
    'start_date': dayKey(pause.start),
    'end_date': pause.end == null ? null : dayKey(pause.end!),
  });

  /// Açık tatili [end] gününde kapatır; [end] başlangıçtan önceyse kaydı siler.
  Future<void> closeOpen(int habitId, DateTime end) async {
    final rows = await _db.query(
      _table,
      where: 'habit_id = ? AND end_date IS NULL',
      whereArgs: [habitId],
    );
    for (final r in rows) {
      final start = parseDayKey(r['start_date'] as String);
      if (dateOnly(end).isBefore(start)) {
        await _db.delete(_table, where: 'id = ?', whereArgs: [r['id']]);
      } else {
        await _db.update(
          _table,
          {'end_date': dayKey(end)},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      }
    }
  }

  static PauseRange _fromRow(Map<String, Object?> r) => PauseRange(
    start: parseDayKey(r['start_date'] as String),
    end: r['end_date'] == null ? null : parseDayKey(r['end_date'] as String),
  );
}
