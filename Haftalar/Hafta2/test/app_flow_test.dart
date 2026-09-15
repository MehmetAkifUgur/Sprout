import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sprout/app.dart';
import 'package:sprout/data/local/app_database.dart';
import 'package:sprout/data/models/habit.dart';
import 'package:sprout/data/repositories/habit_repository.dart';
import 'package:sprout/domain/date_utils.dart';
import 'package:sprout/domain/habit_schedule.dart';
import 'package:sprout/presentation/providers/providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final now = DateTime(2026, 9, 15, 10);
  late AppDatabase database;

  setUpAll(() async {
    sqfliteFfiInit();
    Intl.defaultLocale = 'tr_TR';
    await initializeDateFormatting('tr_TR');
  });

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() => database.close());

  Widget app() => ProviderScope(
    // Her pump yeni bir kapsam: "uygulamayı kapatıp açma" simülasyonu.
    key: UniqueKey(),
    overrides: [
      databaseProvider.overrideWithValue(database),
      clockProvider.overrideWithValue(() => now),
    ],
    child: const SproutApp(),
  );

  testWidgets('ekle, işaretle; puan ve veri yeniden açılışta korunur', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Alışkanlık ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Kitap oku');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Tohum · 0 puan · seri 0'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Tohum · 4 puan · seri 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Tohum · 4 puan · seri 1'), findsOneWidget);
    expect((await HabitRepository(database).getHabits()).single.growthScore, 4);
  });

  testWidgets('evre atlayınca kutlama mesajı gösterilir', (tester) async {
    final repo = HabitRepository(database);
    final start = addDays(dateOnly(now), -4);
    final habit = await repo.addHabit(
      Habit(
        name: 'Yürüyüş',
        targetFrequency: TargetFrequency.daily,
        createdAt: start,
        plantType: 'tree',
      ),
    );
    for (var i = 0; i < 4; i++) {
      await repo.setCompleted(habit.id!, addDays(start, i), true);
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('Tohum ·'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('🎉 Yürüyüş artık bir Filiz!'), findsOneWidget);
  });

  testWidgets('ihmal edilen bitki solmuş görünür', (tester) async {
    final repo = HabitRepository(database);
    final start = addDays(dateOnly(now), -20);
    final habit = await repo.addHabit(
      Habit(
        name: 'Su iç',
        targetFrequency: TargetFrequency.daily,
        createdAt: start,
        plantType: 'cactus',
      ),
    );
    for (var i = 0; i < 10; i++) {
      await repo.setCompleted(habit.id!, addDays(start, i), true);
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('(solmuş)'), findsOneWidget);
  });
}
