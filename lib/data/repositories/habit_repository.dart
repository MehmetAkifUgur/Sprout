import '../../domain/date_utils.dart';
import '../local/app_database.dart';
import '../local/habit_dao.dart';
import '../local/habit_log_dao.dart';
import '../local/settings_dao.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';

/// UI katmanının veritabanı ayrıntılarını bilmeden çalışmasını sağlar.
class HabitRepository {
  HabitRepository(AppDatabase database)
    : _habits = HabitDao(database.db),
      _logs = HabitLogDao(database.db),
      _settings = SettingsDao(database.db);

  final HabitDao _habits;
  final HabitLogDao _logs;
  final SettingsDao _settings;

  static const _onboardingKey = 'onboarding_done';

  Future<List<Habit>> getHabits() => _habits.getAll();

  Future<Habit?> getHabit(int id) => _habits.getById(id);

  Future<Habit> addHabit(Habit habit) async {
    final id = await _habits.insert(habit);
    return habit.copyWith(id: id);
  }

  Future<void> updateHabit(Habit habit) => _habits.update(habit);

  Future<void> updateScore(int habitId, double score) =>
      _habits.updateScore(habitId, score);

  /// Log'lar ON DELETE CASCADE ile birlikte silinir.
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

  Future<bool> isOnboardingDone() async =>
      await _settings.get(_onboardingKey) == 'true';

  Future<void> setOnboardingDone() => _settings.set(_onboardingKey, 'true');

  /// Tüm verileri siler (uygulamayı sıfırla).
  Future<void> resetAll() async {
    await _habits.deleteAll();
    await _settings.clear();
  }
}
