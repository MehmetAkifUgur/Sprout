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
import 'package:sprout/services/notification_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeNotificationService extends NotificationService {
  final synced = <Habit>[];

  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> syncHabit(Habit habit) async => synced.add(habit);
  @override
  Future<void> cancelHabit(int habitId) async {}
  @override
  Future<void> cancelAll() async {}
}

void main() {
  final now = DateTime(2026, 9, 15, 10);
  late AppDatabase database;
  late FakeNotificationService notifications;

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
    notifications = FakeNotificationService();
  });

  tearDown(() => database.close());

  Widget app() => ProviderScope(
    // Her pump yeni bir kapsam: "uygulamayı kapatıp açma" simülasyonu.
    key: UniqueKey(),
    overrides: [
      databaseProvider.overrideWithValue(database),
      notificationServiceProvider.overrideWithValue(notifications),
      clockProvider.overrideWithValue(() => now),
    ],
    child: const SproutApp(),
  );

  Future<void> skipOnboarding() =>
      HabitRepository(database).setOnboardingDone();

  testWidgets('ilk açılışta onboarding gösterilir, geçilince boş bahçe', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Her alışkanlık bir tohum'), findsOneWidget);
    await tester.tap(find.text('Geç'));
    await tester.pumpAndSettle();

    expect(find.text('Bahçen henüz boş'), findsOneWidget);

    // Yeniden açılışta onboarding tekrar gösterilmez.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Bahçen henüz boş'), findsOneWidget);
  });

  testWidgets('alışkanlık ekle, sula; veri yeniden açılışta korunur', (
    tester,
  ) async {
    await skipOnboarding();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tohum ek'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Kitap oku');
    await tester.tap(find.text('Tohumu ek'));
    await tester.pumpAndSettle();

    expect(find.text('Kitap oku'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    expect(notifications.synced.single.name, 'Kitap oku');

    await tester.tap(find.text('Sula'));
    await tester.pumpAndSettle();
    expect(find.text('Tamamlandı'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);

    // Uygulamayı "kapatıp aç".
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Kitap oku'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsOneWidget);

    final habits = await HabitRepository(database).getHabits();
    expect(habits.single.growthScore, greaterThan(0));
  });

  testWidgets('evre atlayınca kutlama mesajı gösterilir', (tester) async {
    await skipOnboarding();
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
    expect(find.text('Tohum · 🔥 4'), findsOneWidget);

    await tester.tap(find.text('Sula'));
    await tester.pumpAndSettle();
    expect(find.text('🎉 Yürüyüş artık bir Filiz!'), findsOneWidget);
  });

  testWidgets('ihmal edilen bitki solmuş görünür ve istatistik açılır', (
    tester,
  ) async {
    await skipOnboarding();
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
    expect(find.textContaining('Soluyor!'), findsOneWidget);

    await tester.tap(find.text('İstatistik'));
    await tester.pumpAndSettle();
    expect(find.text('En uzun seri'), findsOneWidget);
    expect(find.text('10'), findsWidgets);

    await tester.tap(find.text('Son 30 gün'));
    await tester.pumpAndSettle();
    expect(find.text('Aylık oran'), findsOneWidget);
  });

  testWidgets('detay ekranından silme', (tester) async {
    await skipOnboarding();
    await HabitRepository(database).addHabit(
      Habit(
        name: 'Meditasyon',
        targetFrequency: TargetFrequency.weekly,
        createdAt: now,
        plantType: 'sunflower',
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Meditasyon'));
    await tester.pumpAndSettle();
    expect(find.text('Geçmiş'), findsOneWidget);

    await tester.tap(find.byTooltip('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Bahçen henüz boş'), findsOneWidget);
    expect(await HabitRepository(database).getHabits(), isEmpty);
  });
}
