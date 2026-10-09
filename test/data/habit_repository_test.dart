import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/data/local/app_database.dart';
import 'package:sprout/data/models/habit.dart';
import 'package:sprout/data/repositories/habit_repository.dart';
import 'package:sprout/domain/habit_schedule.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late HabitRepository repo;

  Habit sample({String name = 'Kitap oku'}) => Habit(
    name: name,
    targetFrequency: TargetFrequency.custom,
    customDays: {DateTime.monday, DateTime.friday},
    createdAt: DateTime(2026, 9, 1, 8, 30),
    plantType: 'flower',
    reminderMinutes: 20 * 60,
  );

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = HabitRepository(database);
  });

  tearDown(() => database.close());

  test('alışkanlık ekle, listele, güncelle, sil', () async {
    final added = await repo.addHabit(sample());
    expect(added.id, isNotNull);

    var all = await repo.getHabits();
    expect(all, hasLength(1));
    final h = all.single;
    expect(h.name, 'Kitap oku');
    expect(h.targetFrequency, TargetFrequency.custom);
    expect(h.customDays, {DateTime.monday, DateTime.friday});
    expect(h.createdAt, DateTime(2026, 9, 1, 8, 30));
    expect(h.reminderMinutes, 1200);

    await repo.updateHabit(
      h.copyWith(name: 'Yürüyüş', reminderMinutes: () => null),
    );
    await repo.updateScore(h.id!, 42.5);
    final updated = await repo.getHabit(h.id!);
    expect(updated!.name, 'Yürüyüş');
    expect(updated.reminderMinutes, isNull);
    expect(updated.growthScore, 42.5);

    await repo.deleteHabit(h.id!);
    all = await repo.getHabits();
    expect(all, isEmpty);
  });

  test('log upsert gün başına tek kayıt tutar', () async {
    final h = await repo.addHabit(sample());
    final day = DateTime(2026, 9, 7, 23, 59);

    await repo.setCompleted(h.id!, day, true);
    await repo.setCompleted(h.id!, DateTime(2026, 9, 7, 6), true);
    expect(await repo.getLogs(h.id!), hasLength(1));
    expect(await repo.getCompletedDays(h.id!), {DateTime(2026, 9, 7)});

    await repo.setCompleted(h.id!, day, false);
    expect(await repo.getLogs(h.id!), hasLength(1));
    expect(await repo.getCompletedDays(h.id!), isEmpty);
  });

  test('alışkanlık silinince log kayıtları da silinir', () async {
    final a = await repo.addHabit(sample(name: 'A'));
    final b = await repo.addHabit(sample(name: 'B'));
    await repo.setCompleted(a.id!, DateTime(2026, 9, 7), true);
    await repo.setCompleted(b.id!, DateTime(2026, 9, 7), true);

    await repo.deleteHabit(a.id!);
    final all = await repo.getAllCompletedDays();
    expect(all.keys, [b.id]);
  });

  test('onboarding bayrağı ve sıfırlama', () async {
    expect(await repo.isOnboardingDone(), isFalse);
    await repo.setOnboardingDone();
    expect(await repo.isOnboardingDone(), isTrue);

    await repo.addHabit(sample());
    await repo.resetAll();
    expect(await repo.getHabits(), isEmpty);
    expect(await repo.isOnboardingDone(), isFalse);
  });

  test('tatil başlatılır ve bitirilir', () async {
    final h = await repo.addHabit(sample());
    await repo.pauseHabit(h.id!, DateTime(2026, 9, 10));
    await repo.pauseHabit(h.id!, DateTime(2026, 9, 11)); // zaten tatilde
    var habit = (await repo.getHabit(h.id!))!;
    expect(habit.pauses, hasLength(1));
    expect(habit.isPaused, isTrue);

    await repo.resumeHabit(h.id!, DateTime(2026, 9, 14, 9));
    habit = (await repo.getHabit(h.id!))!;
    expect(habit.isPaused, isFalse);
    expect(habit.pauses.single.start, DateTime(2026, 9, 10));
    expect(habit.pauses.single.end, DateTime(2026, 9, 13));
  });

  test('aynı gün başlatılıp bitirilen tatil kaydedilmez', () async {
    final h = await repo.addHabit(sample());
    await repo.pauseHabit(h.id!, DateTime(2026, 9, 10));
    await repo.resumeHabit(h.id!, DateTime(2026, 9, 10));
    expect((await repo.getHabit(h.id!))!.pauses, isEmpty);
  });

  test('yedek dışa aktarılıp içe aktarılınca her şey korunur', () async {
    final h = await repo.addHabit(
      sample().copyWith(
        targetFrequency: TargetFrequency.weekly,
        customDays: {},
        timesPerWeek: 3,
      ),
    );
    await repo.setCompleted(h.id!, DateTime(2026, 9, 2), true);
    await repo.setCompleted(h.id!, DateTime(2026, 9, 3), true);
    await repo.setCompleted(h.id!, DateTime(2026, 9, 4), false);
    await repo.pauseHabit(h.id!, DateTime(2026, 9, 5));
    final json = await repo.exportJson();

    await repo.resetAll();
    expect(await repo.getHabits(), isEmpty);

    expect(await repo.importJson(json), 1);
    final restored = (await repo.getHabits()).single;
    expect(restored.name, 'Kitap oku');
    expect(restored.timesPerWeek, 3);
    expect(restored.reminderMinutes, 1200);
    expect(restored.createdAt, DateTime(2026, 9, 1, 8, 30));
    expect(restored.isPaused, isTrue);
    expect(await repo.getCompletedDays(restored.id!), {
      DateTime(2026, 9, 2),
      DateTime(2026, 9, 3),
    });
  });

  test('bozuk yedek mevcut veriyi değiştirmez', () async {
    await repo.addHabit(sample());
    await expectLater(
      repo.importJson('{"app":"baska"}'),
      throwsFormatException,
    );
    await expectLater(repo.importJson('çöp'), throwsFormatException);
    await expectLater(
      repo.importJson('{"app":"sprout","format":1,"habits":[{"name":1}]}'),
      throwsFormatException,
    );
    expect(await repo.getHabits(), hasLength(1));
  });

  test('sıfırlama öncesi yedek geri yüklenebilir', () async {
    expect(await repo.hasResetBackup(), isFalse);
    final h = await repo.addHabit(sample());
    await repo.setCompleted(h.id!, DateTime(2026, 9, 7), true);
    await repo.setOnboardingDone();

    await repo.resetAll();
    expect(await repo.hasResetBackup(), isTrue);
    expect(await repo.isOnboardingDone(), isFalse);

    await repo.restoreResetBackup();
    final restored = (await repo.getHabits()).single;
    expect(await repo.getCompletedDays(restored.id!), {DateTime(2026, 9, 7)});
    expect(await repo.isOnboardingDone(), isTrue);
  });
}
