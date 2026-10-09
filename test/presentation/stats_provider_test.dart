import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/data/models/habit.dart';
import 'package:sprout/domain/date_utils.dart';
import 'package:sprout/domain/habit_schedule.dart';
import 'package:sprout/presentation/providers/habits_provider.dart';
import 'package:sprout/presentation/providers/stats_provider.dart';

void main() {
  final today = DateTime(2026, 9, 15);

  HabitView view(
    String name,
    TargetFrequency f,
    Set<DateTime> done, {
    int id = 1,
    int daysAgo = 40,
    List<PauseRange> pauses = const [],
  }) => HabitView.compute(
    Habit(
      id: id,
      name: name,
      targetFrequency: f,
      createdAt: addDays(today, -daysAgo),
      plantType: 'flower',
      pauses: pauses,
    ),
    done,
    today,
  );

  Set<DateTime> lastDays(int n, {int skipToday = 0}) => {
    for (var i = skipToday; i < n; i++) addDays(today, -i),
  };

  test('son 30 gün eskiden yeniye sıralanır', () {
    final stats = computeStats([], today);
    expect(stats.days, hasLength(30));
    expect(stats.days.first.day, addDays(today, -29));
    expect(stats.days.last.day, today);
    expect(stats.rateFor(7), isNull);
  });

  test('bugün tamamlanmamış alışkanlık oranı düşürmez', () {
    final stats = computeStats([
      view('A', TargetFrequency.daily, lastDays(7, skipToday: 1)),
    ], today);
    expect(stats.days.last.due, 0);
    expect(stats.rateFor(7), 1);
  });

  test('haftalık alışkanlık gün bazlı orana katılmaz', () {
    final stats = computeStats([
      view('A', TargetFrequency.daily, lastDays(30)),
      view('B', TargetFrequency.weekly, {}, id: 2),
    ], today);
    expect(stats.rateFor(30), 1);
    expect(stats.habits, hasLength(2));
  });

  test('tatil günleri planlı sayılmaz', () {
    final stats = computeStats([
      view(
        'A',
        TargetFrequency.daily,
        {},
        pauses: [PauseRange(start: addDays(today, -10))],
      ),
    ], today);
    expect(stats.rateFor(7), isNull);
  });

  test('toplam tamamlama ve en iyi seri', () {
    final stats = computeStats([
      view('A', TargetFrequency.daily, lastDays(5)),
      view('B', TargetFrequency.daily, lastDays(3), id: 2),
    ], today);
    expect(stats.totalCompletions, 8);
    expect(stats.bestStreak, 5);
  });
}
