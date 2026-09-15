import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const fileName = 'sprout.db';

  /// v1: habits + habit_logs (Hafta 1)
  static const version = 1;

  /// [factory] ve [path] testlerde bellek içi (ffi) veritabanı için verilir.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _createV1(db),
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _createV1(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE habits (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          target_frequency TEXT NOT NULL,
          custom_days TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          plant_type TEXT NOT NULL,
          growth_score REAL NOT NULL DEFAULT 0
        )
      ''')
      ..execute('''
        CREATE TABLE habit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
          date TEXT NOT NULL,
          completed INTEGER NOT NULL,
          UNIQUE(habit_id, date)
        )
      ''')
      ..execute('CREATE INDEX idx_logs_habit ON habit_logs(habit_id)');
    await batch.commit(noResult: true);
  }

  Future<void> close() => db.close();
}
