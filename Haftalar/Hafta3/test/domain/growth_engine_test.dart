import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/core/constants/growth_constants.dart';
import 'package:sprout/domain/date_utils.dart';
import 'package:sprout/domain/growth_engine.dart';
import 'package:sprout/domain/habit_schedule.dart';

void main() {
  final start = DateTime(2026, 3, 2); // Pazartesi

  HabitSchedule daily() =>
      HabitSchedule(frequency: TargetFrequency.daily, startDate: start);

  Set<DateTime> range(int fromOffset, int toOffset) => {
    for (var i = fromOffset; i <= toOffset; i++) addDays(start, i),
  };

  GrowthResult eval(
    HabitSchedule s,
    Set<DateTime> done, {
    required int todayOffset,
  }) => GrowthEngine.evaluate(
    schedule: s,
    completedDays: done,
    today: addDays(start, todayOffset),
  );

  group('GrowthStage', () {
    test('eşik değerleri Bölüm 5 ile uyumlu', () {
      expect(GrowthStage.fromScore(0), GrowthStage.seed);
      expect(GrowthStage.fromScore(20), GrowthStage.seed);
      expect(GrowthStage.fromScore(21), GrowthStage.sprout);
      expect(GrowthStage.fromScore(45), GrowthStage.sprout);
      expect(GrowthStage.fromScore(46), GrowthStage.sapling);
      expect(GrowthStage.fromScore(70), GrowthStage.sapling);
      expect(GrowthStage.fromScore(71), GrowthStage.blooming);
      expect(GrowthStage.fromScore(90), GrowthStage.blooming);
      expect(GrowthStage.fromScore(91), GrowthStage.grown);
      expect(GrowthStage.fromScore(100), GrowthStage.grown);
    });
  });

  group('streak senaryoları', () {
    test('yeni alışkanlık tohum evresinde başlar', () {
      final r = eval(daily(), {}, todayOffset: 0);
      expect(r.score, 0);
      expect(r.stage, GrowthStage.seed);
      expect(r.isWilted, isFalse);
    });

    test('ilk tamamlama taban puan verir', () {
      final r = eval(daily(), range(0, 0), todayOffset: 0);
      expect(r.score, GrowthConstants.dailyBasePoints);
      expect(r.currentStreak, 1);
    });

    test('ardışık günler çarpan etkisi yaratır', () {
      final r = eval(daily(), range(0, 2), todayOffset: 2);
      const b = GrowthConstants.dailyBasePoints;
      expect(r.score, closeTo(b * 1.0 + b * 1.1 + b * 1.2, 1e-9));
      expect(r.currentStreak, 3);
      expect(r.longestStreak, 3);
    });

    test('streak çarpanı üst sınırı aşmaz', () {
      expect(
        GrowthEngine.streakMultiplier(1000),
        GrowthConstants.maxStreakMultiplier,
      );
    });

    test('kesintisiz tamamlama sonunda tam büyümüş evreye ulaşır', () {
      final r = eval(daily(), range(0, 29), todayOffset: 29);
      expect(r.score, GrowthConstants.maxScore);
      expect(r.stage, GrowthStage.grown);
    });

    test('ara verilince streak sıfırlanır ama en uzun streak korunur', () {
      final done = {...range(0, 4), ...range(6, 7)};
      final r = eval(daily(), done, todayOffset: 7);
      expect(r.currentStreak, 2);
      expect(r.longestStreak, 5);
    });

    test('bugün henüz tamamlanmadıysa streak bozulmaz', () {
      final r = eval(daily(), range(0, 3), todayOffset: 4);
      expect(r.currentStreak, 4);
      expect(r.missedInARow, 0);
    });
  });

  group('ihmal senaryoları', () {
    test('tolerans süresi içinde puan düşmez', () {
      final before = eval(daily(), range(0, 4), todayOffset: 4).score;
      final after = eval(daily(), range(0, 4), todayOffset: 6);
      expect(after.missedInARow, GrowthConstants.gracePeriods);
      expect(after.score, before);
    });

    test('tolerans aşılınca ceza artarak uygulanır', () {
      final before = eval(daily(), range(0, 9), todayOffset: 9).score;
      // 10, 11, 12. günler kaçırıldı; bugün 13.
      final after = eval(daily(), range(0, 9), todayOffset: 13);
      final expected =
          before -
          GrowthEngine.decayFor(1) -
          GrowthEngine.decayFor(2) -
          GrowthEngine.decayFor(3);
      expect(GrowthEngine.decayFor(1), 0);
      expect(GrowthEngine.decayFor(2), GrowthConstants.decayBase);
      expect(
        GrowthEngine.decayFor(3),
        GrowthConstants.decayBase + GrowthConstants.decayIncrement,
      );
      expect(after.score, closeTo(expected, 1e-9));
    });

    test('ceza tek dönemde üst sınırı aşmaz', () {
      expect(GrowthEngine.decayFor(100), GrowthConstants.maxDecayPerPeriod);
    });

    test('N gün ihmal sonrası bitki solar', () {
      final n = GrowthConstants.wiltAfterMissedDaily;
      final almost = eval(daily(), range(0, 9), todayOffset: 9 + n);
      expect(almost.missedInARow, n - 1);
      expect(almost.isWilted, isFalse);

      final wilted = eval(daily(), range(0, 9), todayOffset: 10 + n);
      expect(wilted.isWilted, isTrue);
    });

    test('solmuş bitki tamamlanınca canlanır', () {
      final done = {...range(0, 9), addDays(start, 20)};
      final r = eval(daily(), done, todayOffset: 20);
      expect(r.isWilted, isFalse);
      expect(r.currentStreak, 1);
    });

    test('puan sıfırın altına inmez', () {
      final r = eval(daily(), {}, todayOffset: 60);
      expect(r.score, 0);
      expect(r.isWilted, isTrue);
    });
  });

  group('özel günler', () {
    test('seçili olmayan günler kaçırılmış sayılmaz', () {
      final s = HabitSchedule(
        frequency: TargetFrequency.custom,
        customDays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
        startDate: start,
      );
      // Pzt, Çar, Cum tamamlandı; bugün sonraki Pazar.
      final done = {addDays(start, 0), addDays(start, 2), addDays(start, 4)};
      final r = eval(s, done, todayOffset: 6);
      expect(r.currentStreak, 3);
      expect(r.missedInARow, 0);
    });

    test('seçili olmayan günde yapılan tamamlama puan vermez', () {
      final s = HabitSchedule(
        frequency: TargetFrequency.custom,
        customDays: {DateTime.monday},
        startDate: start,
      );
      final r = eval(s, {addDays(start, 1)}, todayOffset: 1);
      expect(r.score, 0);
    });
  });

  group('haftalık', () {
    HabitSchedule weekly() =>
        HabitSchedule(frequency: TargetFrequency.weekly, startDate: start);

    test('hafta içinde herhangi bir gün tamamlamak yeterli', () {
      final r = eval(weekly(), {addDays(start, 5)}, todayOffset: 5);
      expect(r.score, GrowthConstants.weeklyBasePoints);
      expect(r.currentStreak, 1);
    });

    test('açık hafta henüz kaçırılmış sayılmaz', () {
      final r = eval(weekly(), {}, todayOffset: 6);
      expect(r.missedInARow, 0);
    });

    test('kaçırılan haftalar soldurur', () {
      final r = eval(weekly(), {
        addDays(start, 0),
      }, todayOffset: 7 * (GrowthConstants.wiltAfterMissedWeekly + 1));
      expect(r.missedInARow, GrowthConstants.wiltAfterMissedWeekly);
      expect(r.isWilted, isTrue);
    });
  });

  group('completionRate', () {
    test('açık ve tamamlanmamış dönem oranı düşürmez', () {
      final rate = GrowthEngine.completionRate(
        schedule: daily(),
        completedDays: range(0, 1),
        from: start,
        to: addDays(start, 3),
        today: addDays(start, 3),
      );
      // gün 0,1 tamam; gün 2 kaçırıldı; gün 3 bugün (sayılmaz)
      expect(rate, closeTo(2 / 3, 1e-9));
    });

    test('başlangıçtan önceki aralık için null döner', () {
      final rate = GrowthEngine.completionRate(
        schedule: daily(),
        completedDays: {},
        from: addDays(start, -10),
        to: addDays(start, -1),
        today: start,
      );
      expect(rate, isNull);
    });
  });

  test('yaz saati geçişi gün sayımını bozmaz', () {
    final s = HabitSchedule(
      frequency: TargetFrequency.daily,
      startDate: DateTime(2026, 3, 27),
    );
    final done = {for (var i = 0; i < 5; i++) DateTime(2026, 3, 27 + i)};
    final r = GrowthEngine.evaluate(
      schedule: s,
      completedDays: done,
      today: DateTime(2026, 3, 31),
    );
    expect(r.currentStreak, 5);
  });
}
