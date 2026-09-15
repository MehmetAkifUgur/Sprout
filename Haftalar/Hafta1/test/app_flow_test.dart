import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sprout/app.dart';
import 'package:sprout/data/local/app_database.dart';
import 'package:sprout/data/repositories/habit_repository.dart';
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

  // Her pump yeni bir uygulama örneği: "kapatıp açma" simülasyonu.
  Widget app() => SproutApp(
    key: UniqueKey(),
    repository: HabitRepository(database),
    clock: () => now,
  );

  testWidgets('ekle, işaretle, yeniden açılışta veri korunur, sil', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Henüz alışkanlık yok'), findsOneWidget);

    await tester.tap(find.byTooltip('Alışkanlık ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Kitap oku');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Kitap oku'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    // Uygulamayı "kapatıp aç".
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Kitap oku'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.drag(find.text('Kitap oku'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Henüz alışkanlık yok'), findsOneWidget);
    expect(await HabitRepository(database).getHabits(), isEmpty);
  });
}
