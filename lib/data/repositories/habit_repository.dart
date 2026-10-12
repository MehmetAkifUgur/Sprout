import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/date_utils.dart';
import '../../domain/habit_schedule.dart';
import '../local/app_database.dart';
import '../local/habit_dao.dart';
import '../local/habit_log_dao.dart';
import '../local/pause_dao.dart';
import '../local/settings_dao.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';

/// UI katmanının veritabanı ayrıntılarını bilmeden çalışmasını sağlar.
class HabitRepository {
  HabitRepository(AppDatabase database)
    : _db = database.db,
      _habits = HabitDao(database.db),
      _logs = HabitLogDao(database.db),
      _pauses = PauseDao(database.db),
      _settings = SettingsDao(database.db);

  final Database _db;
  final HabitDao _habits;
  final HabitLogDao _logs;
  final PauseDao _pauses;
  final SettingsDao _settings;

  static const _onboardingKey = 'onboarding_done';
  static const _resetBackupKey = 'backup_before_reset';

  /// Yedek dosyasının biçim sürümü (DB şema sürümünden bağımsız).
  static const backupFormat = 1;

  /// Tatil aralıkları eklenmiş olarak tüm alışkanlıklar.
  Future<List<Habit>> getHabits() async {
    final habits = await _habits.getAll();
    final pauses = await _pauses.getAll();
    return [for (final h in habits) h.copyWith(pauses: pauses[h.id] ?? [])];
  }

  Future<Habit?> getHabit(int id) async {
    final habit = await _habits.getById(id);
    return habit?.copyWith(pauses: await _pauses.getForHabit(id));
  }

  Future<Habit> addHabit(Habit habit) async {
    final id = await _habits.insert(habit);
    return habit.copyWith(id: id);
  }

  Future<void> updateHabit(Habit habit) => _habits.update(habit);

  Future<void> updateScore(int habitId, double score) =>
      _habits.updateScore(habitId, score);

  /// Log'lar ve tatiller ON DELETE CASCADE ile birlikte silinir.
  Future<void> deleteHabit(int id) => _habits.delete(id);

  Future<void> setCompleted(int habitId, DateTime date, bool completed) =>
      _logs.upsert(
        HabitLog(habitId: habitId, date: dateOnly(date), completed: completed),
      );

  Future<List<HabitLog>> getLogs(int habitId) => _logs.getForHabit(habitId);

  Future<Set<DateTime>> getCompletedDays(int habitId) async {
    final logs = await _logs.getForHabit(habitId);
    return {
      for (final l in logs)
        if (l.completed) l.date,
    };
  }

  /// habitId -> tamamlanan günler.
  Future<Map<int, Set<DateTime>>> getAllCompletedDays() async {
    final result = <int, Set<DateTime>>{};
    for (final log in await _logs.getAll()) {
      if (!log.completed) continue;
      result.putIfAbsent(log.habitId, () => {}).add(log.date);
    }
    return result;
  }

  /// [day] gününden itibaren tatile alır (zaten tatildeyse bir şey yapmaz).
  Future<void> pauseHabit(int habitId, DateTime day) async {
    final pauses = await _pauses.getForHabit(habitId);
    if (pauses.any((p) => p.end == null)) return;
    await _pauses.insert(habitId, PauseRange(start: dateOnly(day)));
  }

  /// Tatili bitirir: [day] yeniden normal sayılır, son tatil günü bir önceki gün.
  Future<void> resumeHabit(int habitId, DateTime day) =>
      _pauses.closeOpen(habitId, addDays(dateOnly(day), -1));

  Future<bool> isOnboardingDone() async =>
      await _settings.get(_onboardingKey) == 'true';

  Future<void> setOnboardingDone() => _settings.set(_onboardingKey, 'true');

  /// Tüm verileri siler (uygulamayı sıfırla). Silmeden önce bir yedek saklanır,
  /// [restoreResetBackup] ile geri getirilebilir.
  Future<void> resetAll() async {
    final habits = await _habits.getAll();
    if (habits.isNotEmpty) {
      await _settings.set(_resetBackupKey, await exportJson());
    }
    await _habits.deleteAll();
    await _settings.clear(keep: {_resetBackupKey});
  }

  Future<bool> hasResetBackup() async =>
      await _settings.get(_resetBackupKey) != null;

  /// Sıfırlamadan önce alınan yedeği geri yükler.
  Future<void> restoreResetBackup() async {
    final json = await _settings.get(_resetBackupKey);
    if (json == null) return;
    await importJson(json);
    await setOnboardingDone();
  }

  /// Tüm alışkanlıkları, kayıtları ve tatilleri JSON metni olarak dışa aktarır.
  Future<String> exportJson() async {
    final habits = await getHabits();
    final days = await getAllCompletedDays();
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'sprout',
      'format': backupFormat,
      'habits': [
        for (final h in habits)
          {
            ...h.toMap()
              ..remove('id')
              ..remove('growth_score'),
            'completed': [
              for (final d in (days[h.id] ?? {}).toList()..sort()) dayKey(d),
            ],
            'pauses': [
              for (final p in h.pauses)
                {
                  'start': dayKey(p.start),
                  'end': p.end == null ? null : dayKey(p.end!),
                },
            ],
          },
      ],
    });
  }

  /// [exportJson] çıktısını içe aktarır. Mevcut alışkanlıkların yerini alır.
  /// Geçersiz veride hiçbir şey değişmez ve [FormatException] atılır.
  Future<int> importJson(String json) async {
    final parsed = _parseBackup(json);
    await _db.transaction((txn) async {
      await txn.delete('habits');
      for (final entry in parsed) {
        final id = await txn.insert('habits', entry.habit.toMap());
        final logs = HabitLogDao(txn);
        for (final d in entry.completed) {
          await logs.upsert(HabitLog(habitId: id, date: d, completed: true));
        }
        final pauses = PauseDao(txn);
        for (final p in entry.habit.pauses) {
          await pauses.insert(id, p);
        }
      }
    });
    return parsed.length;
  }

  static List<({Habit habit, List<DateTime> completed})> _parseBackup(
    String json,
  ) {
    try {
      final root = jsonDecode(json);
      if (root is! Map || root['app'] != 'sprout') {
        throw const FormatException('Bu bir Sprout yedeği değil.');
      }
      if ((root['format'] as int) > backupFormat) {
        throw const FormatException(
          'Yedek daha yeni bir sürümle alınmış, önce uygulamayı güncelle.',
        );
      }
      return [
        for (final raw in root['habits'] as List)
          (
            habit:
                Habit.fromMap({
                  ...(raw as Map).cast<String, Object?>(),
                  'growth_score': 0,
                }).copyWith(
                  pauses: [
                    for (final p in raw['pauses'] as List? ?? const [])
                      PauseRange(
                        start: parseDayKey(p['start'] as String),
                        end: p['end'] == null
                            ? null
                            : parseDayKey(p['end'] as String),
                      ),
                  ],
                ),
            completed: [
              for (final d in raw['completed'] as List? ?? const [])
                parseDayKey(d as String),
            ],
          ),
      ];
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Yedek okunamadı: biçim bozuk.');
    }
  }
}
