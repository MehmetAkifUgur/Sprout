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

    await repo.updateHabit(h.copyWith(name: 'Yürüyüş'));
    await repo.updateScore(h.id!, 42.5);
    final updated = await repo.getHabit(h.id!);
    expect(updated!.name, 'Yürüyüş');
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
}
