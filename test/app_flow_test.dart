import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
  final notBefore = <DateTime?>[];

  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> syncHabit(Habit habit, {DateTime? notBefore}) async {
    synced.add(habit);
    this.notBefore.add(notBefore);
  }

  @override
  Future<void> cancelHabit(int habitId) async {}
  @override
  Future<void> cancelAll() async {}
}

/// Sistem dosya ekranı yerine belleğe yazıp okuyan sahte seçici.
class FakeFilePicker extends FilePickerPlatform {
  Uint8List? saved;
  String? savedName;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saved = bytes;
    savedName = fileName;
    return Uri.parse('content://test/$fileName');
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => saved == null ? null : _MemoryFile(savedName!, saved!);
}

final class _MemoryFile extends PlatformFile {
  _MemoryFile(this.name, this.bytes);

  @override
  final String name;
  final Uint8List bytes;

  @override
  Uri get uri => Uri.parse('content://test/$name');
  @override
  get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
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
    // Bugün tamamlandı: hatırlatma yarından başlar.
    expect(notifications.notBefore.last, addDays(dateOnly(now), 1));

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

  testWidgets('sulama geri alınabilir', (tester) async {
    await skipOnboarding();
    await HabitRepository(database).addHabit(
      Habit(
        name: 'Esneme',
        targetFrequency: TargetFrequency.daily,
        createdAt: now,
        plantType: 'flower',
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sula'));
    await tester.pumpAndSettle();
    expect(find.text('Esneme sulandı 💧'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsOneWidget);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(find.text('Sula'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('tatile alınan bitki solmaz, tatil bitirilebilir', (
    tester,
  ) async {
    await skipOnboarding();
    final repo = HabitRepository(database);
    final start = addDays(dateOnly(now), -10);
    final habit = await repo.addHabit(
      Habit(
        name: 'Koşu',
        targetFrequency: TargetFrequency.daily,
        createdAt: start,
        plantType: 'tree',
      ),
    );
    for (var i = 0; i < 5; i++) {
      await repo.setCompleted(habit.id!, addDays(start, i), true);
    }
    await repo.pauseHabit(habit.id!, addDays(start, 5));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Tatilde 🌴'), findsOneWidget);
    expect(find.textContaining('Soluyor!'), findsNothing);
    // Tatilde bugün beklenen alışkanlık yok.
    expect(find.text('0/0'), findsOneWidget);

    await tester.tap(find.text('Koşu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tarihinden beri tatilde'), findsOneWidget);

    await tester.tap(find.byTooltip('Tatili bitir'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tatile al'), findsOneWidget);
    expect((await repo.getHabit(habit.id!))!.isPaused, isFalse);
  });

  testWidgets('sıklık değişince puan önizlemesiyle onay istenir', (
    tester,
  ) async {
    await skipOnboarding();
    final repo = HabitRepository(database);
    final start = addDays(dateOnly(now), -6);
    final habit = await repo.addHabit(
      Habit(
        name: 'Okuma',
        targetFrequency: TargetFrequency.daily,
        createdAt: start,
        plantType: 'flower',
      ),
    );
    for (var i = 0; i < 6; i++) {
      await repo.setCompleted(habit.id!, addDays(start, i), true);
    }
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Okuma'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Düzenle'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Haftalık'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Sıklık değişsin mi?'), findsOneWidget);
    expect(find.textContaining('Puan: '), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(
      (await repo.getHabit(habit.id!))!.targetFrequency,
      TargetFrequency.daily,
    );
  });

  testWidgets('yedek dosyaya kaydedilir ve geri yüklenir', (tester) async {
    final picker = FakeFilePicker();
    FilePickerPlatform.instance = picker;
    await skipOnboarding();
    final repo = HabitRepository(database);
    final habit = await repo.addHabit(
      Habit(
        name: 'Günlük yaz',
        targetFrequency: TargetFrequency.daily,
        createdAt: addDays(dateOnly(now), -2),
        plantType: 'cactus',
      ),
    );
    await repo.setCompleted(habit.id!, addDays(dateOnly(now), -1), true);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yedeği dışa aktar'));
    await tester.pumpAndSettle();
    expect(find.text('Yedek kaydedildi 🌱'), findsOneWidget);
    expect(picker.savedName, 'sprout-yedek-2026-09-15.json');

    await repo.deleteHabit(habit.id!);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Bahçen henüz boş'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yedeği içe aktar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geri yükle'));
    await tester.pumpAndSettle();

    expect(find.text('Günlük yaz'), findsOneWidget);
    final restored = (await repo.getHabits()).single;
    expect(await repo.getCompletedDays(restored.id!), {
      addDays(dateOnly(now), -1),
    });
  });
}
