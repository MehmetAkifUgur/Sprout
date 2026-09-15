import '../core/constants/growth_constants.dart';
import 'date_utils.dart';
import 'habit_schedule.dart';

/// Tek bir değerlendirme dönemi (bir gün ya da 7 günlük blok).
class Period {
  const Period({
    required this.start,
    required this.end,
    required this.completed,
    required this.isOpen,
  });

  final DateTime start;

  /// Dahil.
  final DateTime end;
  final bool completed;

  /// Bugünü içeren, henüz bitmemiş dönem. Tamamlanmamışsa ceza verilmez.
  final bool isOpen;
}

class GrowthResult {
  const GrowthResult({
    required this.score,
    required this.currentStreak,
    required this.longestStreak,
    required this.missedInARow,
    required this.isWilted,
  });

  static const initial = GrowthResult(
    score: 0,
    currentStreak: 0,
    longestStreak: 0,
    missedInARow: 0,
    isWilted: false,
  );

  final double score;
  final int currentStreak;
  final int longestStreak;

  /// Son ardışık kaçırılmış (kapanmış) dönem sayısı.
  final int missedInARow;
  final bool isWilted;

  GrowthStage get stage => GrowthStage.fromScore(score);
}

/// Büyüme/solma hesaplama mantığı.
///
/// UI ve veritabanından tamamen bağımsızdır: yalnızca plan ve tamamlanan günler
/// alır, puanı her seferinde baştan yeniden oynatarak (replay) hesaplar. Bu
/// sayede geçmiş bir günün düzenlenmesi ya da uygulamanın günlerce açılmaması
/// her zaman tutarlı sonuç verir.
class GrowthEngine {
  const GrowthEngine._();

  static GrowthResult evaluate({
    required HabitSchedule schedule,
    required Set<DateTime> completedDays,
    required DateTime today,
  }) {
    final periods = periodsBetween(
      schedule: schedule,
      completedDays: completedDays,
      from: schedule.startDate,
      to: today,
      today: today,
    );

    final base = schedule.frequency == TargetFrequency.weekly
        ? GrowthConstants.weeklyBasePoints
        : GrowthConstants.dailyBasePoints;

    var score = GrowthConstants.minScore;
    var streak = 0;
    var longest = 0;
    var missed = 0;

    for (final period in periods) {
      if (period.completed) {
        streak++;
        missed = 0;
        if (streak > longest) longest = streak;
        score += base * streakMultiplier(streak);
      } else if (period.isOpen) {
        continue;
      } else {
        streak = 0;
        missed++;
        score -= decayFor(missed);
      }
      score = score.clamp(GrowthConstants.minScore, GrowthConstants.maxScore);
    }

    final wiltThreshold = schedule.frequency == TargetFrequency.weekly
        ? GrowthConstants.wiltAfterMissedWeekly
        : GrowthConstants.wiltAfterMissedDaily;

    return GrowthResult(
      score: score,
      currentStreak: streak,
      longestStreak: longest,
      missedInARow: missed,
      isWilted: missed >= wiltThreshold,
    );
  }

  /// Ardışık [streak]. tamamlamanın puan çarpanı (1. tamamlama = 1.0).
  static double streakMultiplier(int streak) {
    if (streak <= 0) return 1;
    final m = 1 + (streak - 1) * GrowthConstants.streakBonusPerPeriod;
    return m > GrowthConstants.maxStreakMultiplier
        ? GrowthConstants.maxStreakMultiplier
        : m;
  }

  /// Ardışık [missed]. kaçırılan dönemin cezası.
  static double decayFor(int missed) {
    final over = missed - GrowthConstants.gracePeriods;
    if (over <= 0) return 0;
    final d =
        GrowthConstants.decayBase + (over - 1) * GrowthConstants.decayIncrement;
    return d > GrowthConstants.maxDecayPerPeriod
        ? GrowthConstants.maxDecayPerPeriod
        : d;
  }

  /// [from]–[to] aralığındaki (dahil) dönemler, kronolojik sırayla.
  static List<Period> periodsBetween({
    required HabitSchedule schedule,
    required Set<DateTime> completedDays,
    required DateTime from,
    required DateTime to,
    required DateTime today,
  }) {
    final start = dateOnly(schedule.startDate);
    final todayDay = dateOnly(today);
    var cursor = dateOnly(from).isBefore(start) ? start : dateOnly(from);
    var last = dateOnly(to).isAfter(todayDay) ? todayDay : dateOnly(to);
    final days = completedDays.map(dateOnly).toSet();
    final periods = <Period>[];
    if (cursor.isAfter(last)) return periods;

    if (schedule.frequency == TargetFrequency.weekly) {
      cursor = schedule.weekPeriodStart(cursor);
      while (!cursor.isAfter(last)) {
        final end = addDays(cursor, 6);
        var completed = false;
        for (var d = cursor; !d.isAfter(end); d = addDays(d, 1)) {
          if (days.contains(d)) {
            completed = true;
            break;
          }
        }
        periods.add(
          Period(
            start: cursor,
            end: end,
            completed: completed,
            isOpen: !end.isBefore(todayDay),
          ),
        );
        cursor = addDays(cursor, 7);
      }
      return periods;
    }

    for (var d = cursor; !d.isAfter(last); d = addDays(d, 1)) {
      if (!schedule.isDueOn(d)) continue;
      periods.add(
        Period(
          start: d,
          end: d,
          completed: days.contains(d),
          isOpen: d == todayDay,
        ),
      );
    }
    return periods;
  }

  /// Aralıktaki tamamlanma oranı (0–1). Açık ve tamamlanmamış dönem sayılmaz.
  /// Değerlendirilecek dönem yoksa null.
  static double? completionRate({
    required HabitSchedule schedule,
    required Set<DateTime> completedDays,
    required DateTime from,
    required DateTime to,
    required DateTime today,
  }) {
    final periods = periodsBetween(
      schedule: schedule,
      completedDays: completedDays,
      from: from,
      to: to,
      today: today,
    ).where((p) => p.completed || !p.isOpen).toList();
    if (periods.isEmpty) return null;
    return periods.where((p) => p.completed).length / periods.length;
  }
}
