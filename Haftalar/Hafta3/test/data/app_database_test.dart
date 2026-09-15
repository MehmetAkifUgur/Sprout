import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sprout/data/local/app_database.dart';
import 'package:sprout/data/repositories/habit_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('v1 veritabanı veri kaybetmeden son sürüme yükseltilir', () async {
    final dir = await Directory.systemTemp.createTemp('sprout_migration');
    final path = p.join(dir.path, 'sprout.db');

    // Hafta 1 sürümündeki şema.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE habits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              target_frequency TEXT NOT NULL,
              custom_days TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              plant_type TEXT NOT NULL,
              growth_score REAL NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE habit_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
              date TEXT NOT NULL,
              completed INTEGER NOT NULL,
              UNIQUE(habit_id, date)
            )
          ''');
        },
      ),
    );
    await v1.insert('habits', {
      'name': 'Eski alışkanlık',
      'target_frequency': 'daily',
      'custom_days': '',
      'created_at': DateTime(2026, 8, 1).toIso8601String(),
      'plant_type': 'tree',
      'growth_score': 12.0,
    });
    await v1.close();

    final database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final repo = HabitRepository(database);

    final habit = (await repo.getHabits()).single;
    expect(habit.name, 'Eski alışkanlık');
    expect(habit.reminderMinutes, isNull);
    expect(await database.db.getVersion(), AppDatabase.version);

    await database.close();
    await dir.delete(recursive: true);
  });
}
