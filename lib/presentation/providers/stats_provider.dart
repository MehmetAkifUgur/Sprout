import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_utils.dart';
import '../../domain/growth_engine.dart';
import '../../domain/habit_schedule.dart';
import 'habits_provider.dart';

class DayStat {
  const DayStat(this.day, this.completed, this.due);

  final DateTime day;
  final int completed;

  /// O gün planlı (günlük/özel) alışkanlık sayısı.
  final int due;

  double? get rate => due == 0 ? null : completed / due;
}

class HabitStat {
  const HabitStat(this.view, this.rate7, this.rate30);

  final HabitView view;
  final double? rate7;
  final double? rate30;
}

class StatsData {
  const StatsData({
    required this.days,
    required this.habits,
    required this.totalCompletions,
    required this.bestStreak,
  });

  /// Son 30 gün, eskiden yeniye.
  final List<DayStat> days;
  final List<HabitStat> habits;
  final int totalCompletions;
  final int bestStreak;

  double? rateFor(int lastDays) {
    var done = 0, due = 0;
    for (final d in days.skip(days.length - lastDays)) {
      done += d.completed;
      due += d.due;
    }
    return due == 0 ? null : done / due;
  }
}

/// Saf hesaplama; testte doğrudan çağrılabilir.
StatsData computeStats(List<HabitView> views, DateTime today) {
  final t = dateOnly(today);
  final days = <DayStat>[];
  for (var i = 29; i >= 0; i--) {
    final day = addDays(t, -i);
    var due = 0, done = 0;
    for (final v in views) {
      // Haftalık alışkanlıklar gün bazlı orana katılmaz; kendi kartında görünür.
      if (v.habit.targetFrequency == TargetFrequency.weekly) continue;
      if (!v.habit.schedule.isDueOn(day)) continue;
      final completed = v.completedDays.contains(day);
      // Bugün henüz tamamlanmamış olanlar oranı düşürmesin.
      if (day == t && !completed) continue;
      due++;
      if (completed) done++;
    }
    days.add(DayStat(day, done, due));
  }

  double? rate(HabitView v, int n) => GrowthEngine.completionRate(
    schedule: v.habit.schedule,
    completedDays: v.completedDays,
    from: addDays(t, -(n - 1)),
    to: t,
    today: t,
  );

  return StatsData(
    days: days,
    habits: [for (final v in views) HabitStat(v, rate(v, 7), rate(v, 30))],
    totalCompletions: views.fold(0, (s, v) => s + v.completedDays.length),
    bestStreak: views.fold(
      0,
      (s, v) => v.growth.longestStreak > s ? v.growth.longestStreak : s,
    ),
  );
}

final statsProvider = Provider<AsyncValue<StatsData>>((ref) {
  return ref
      .watch(habitsProvider)
      .whenData(
        (views) =>
            computeStats(views, views.firstOrNull?.today ?? DateTime.now()),
      );
});
