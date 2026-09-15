import 'package:sqflite/sqflite.dart';

import '../models/habit.dart';

class HabitDao {
  const HabitDao(this._db);

  final Database _db;
  static const _table = 'habits';

  Future<int> insert(Habit habit) => _db.insert(_table, habit.toMap());

  Future<List<Habit>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'created_at ASC, id ASC');
    return rows.map(Habit.fromMap).toList();
  }

  Future<Habit?> getById(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Habit.fromMap(rows.first);
  }

  Future<int> update(Habit habit) =>
      _db.update(_table, habit.toMap(), where: 'id = ?', whereArgs: [habit.id]);

  Future<void> updateScore(int id, double score) => _db.update(
    _table,
    {'growth_score': score},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<int> delete(int id) =>
      _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteAll() => _db.delete(_table);
}
