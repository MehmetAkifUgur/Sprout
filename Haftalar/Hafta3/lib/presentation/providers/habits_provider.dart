import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/growth_constants.dart';
import '../../data/models/habit.dart';
import '../../domain/date_utils.dart';
import '../../domain/growth_engine.dart';
import '../../domain/habit_schedule.dart';
import 'providers.dart';

/// Bir alışkanlığın UI için hazırlanmış anlık görünümü.
class HabitView {
  const HabitView({
    required this.habit,
    required this.completedDays,
    required this.growth,
    required this.today,
  });

  final Habit habit;
  final Set<DateTime> completedDays;
  final GrowthResult growth;
  final DateTime today;

  int get id => habit.id!;
  GrowthStage get stage => growth.stage;

  bool get completedToday => completedDays.contains(today);

  bool get dueToday => habit.schedule.isDueOn(today);

  /// Günlük/özel: bugün tamamlandı mı. Haftalık: bu hafta bloğunda tamamlandı mı.
  bool get doneThisPeriod {
    if (habit.targetFrequency != TargetFrequency.weekly) return completedToday;
    final start = habit.schedule.weekPeriodStart(today);
    return completedDays.any(
      (d) => !d.isBefore(start) && d.isBefore(addDays(start, 7)),
    );
  }

  static HabitView compute(Habit habit, Set<DateTime> days, DateTime now) {
    final today = dateOnly(now);
    final growth = GrowthEngine.evaluate(
      schedule: habit.schedule,
      completedDays: days,
      today: today,
    );
    return HabitView(
      habit: habit.copyWith(growthScore: growth.score),
      completedDays: days,
      growth: growth,
      today: today,
    );
  }
}

/// Toggle sonrası evre değiştiyse UI'ın kutlama/uyarı göstermesi için döner.
class StageChange {
  const StageChange(this.habitName, this.from, this.to);
  final String habitName;
  final GrowthStage from;
  final GrowthStage to;
  bool get isUp => to.index > from.index;
}

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<HabitView>>(
  HabitsNotifier.new,
);

class HabitsNotifier extends AsyncNotifier<List<HabitView>> {
  @override
  Future<List<HabitView>> build() async {
    final repo = ref.watch(habitRepositoryProvider);
    final now = ref.watch(clockProvider)();

    final habits = await repo.getHabits();
    final allDays = await repo.getAllCompletedDays();
    final views = <HabitView>[];
    for (final habit in habits) {
      final view = HabitView.compute(habit, allDays[habit.id] ?? {}, now);
      // Gün değişimiyle oluşan solma/büyüme DB'deki önbellek puana yansıtılır.
      if ((view.growth.score - habit.growthScore).abs() > 1e-6) {
        await repo.updateScore(view.id, view.growth.score);
      }
      views.add(view);
    }
    return views;
  }

  Future<Habit> addHabit(Habit habit) async {
    final saved = await ref.read(habitRepositoryProvider).addHabit(habit);
    await _syncReminder(saved);
    ref.invalidateSelf();
    await future;
    return saved;
  }

  Future<void> updateHabit(Habit habit) async {
    await ref.read(habitRepositoryProvider).updateHabit(habit);
    await _syncReminder(habit);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteHabit(int id) async {
    await ref.read(habitRepositoryProvider).deleteHabit(id);
    try {
      await ref.read(notificationServiceProvider).cancelHabit(id);
    } catch (_) {}
    final current = state.value;
    if (current != null) {
      state = AsyncData([...current.where((v) => v.id != id)]);
    }
  }

  Future<StageChange?> toggleToday(int habitId) {
    return toggleDay(habitId, ref.read(clockProvider)());
  }

  Future<StageChange?> toggleDay(int habitId, DateTime day) async {
    final current = await future;
    final index = current.indexWhere((v) => v.id == habitId);
    if (index < 0) return null;
    final old = current[index];
    final date = dateOnly(day);
    final now = ref.read(clockProvider)();
    if (date.isAfter(dateOnly(now)) ||
        date.isBefore(dateOnly(old.habit.createdAt))) {
      return null;
    }

    final nowCompleted = !old.completedDays.contains(date);
    final repo = ref.read(habitRepositoryProvider);
    await repo.setCompleted(habitId, date, nowCompleted);

    final days = {...old.completedDays};
    nowCompleted ? days.add(date) : days.remove(date);
    final updated = HabitView.compute(old.habit, days, now);
    await repo.updateScore(habitId, updated.growth.score);

    final next = [...current]..[index] = updated;
    state = AsyncData(next);

    return old.stage == updated.stage
        ? null
        : StageChange(old.habit.name, old.stage, updated.stage);
  }

  Future<void> _syncReminder(Habit habit) async {
    try {
      await ref.read(notificationServiceProvider).syncHabit(habit);
    } catch (_) {
      // Bildirim altyapısı yoksa (ör. test ortamı) alışkanlık yine kaydedilir.
    }
  }
}
