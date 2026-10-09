import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location istanbul;

  setUpAll(() {
    tz_data.initializeTimeZones();
    istanbul = tz.getLocation('Europe/Istanbul');
  });

  // 15 Eylül 2026 Salı, 10:00.
  tz.TZDateTime at(int day, int hour, [int minute = 0]) =>
      tz.TZDateTime(istanbul, 2026, 9, day, hour, minute);

  test('saat henüz gelmediyse bugün çalar', () {
    expect(NotificationService.nextReminder(at(15, 10), 20 * 60), at(15, 20));
  });

  test('saat geçtiyse yarın çalar', () {
    expect(NotificationService.nextReminder(at(15, 21), 20 * 60), at(16, 20));
  });

  test('bugün tamamlandıysa yarından başlar', () {
    expect(
      NotificationService.nextReminder(
        at(15, 10),
        20 * 60,
        notBefore: DateTime(2026, 9, 16),
      ),
      at(16, 20),
    );
  });

  test('özel gün: bir sonraki seçili hafta gününe denk gelir', () {
    final next = NotificationService.nextReminder(
      at(15, 10),
      8 * 60 + 30,
      weekday: DateTime.friday,
    );
    expect(next, at(18, 8, 30));
  });

  test('özel gün bugün tamamlandıysa gelecek haftaya kayar', () {
    final next = NotificationService.nextReminder(
      at(15, 10),
      20 * 60,
      weekday: DateTime.tuesday,
      notBefore: DateTime(2026, 9, 16),
    );
    expect(next, at(22, 20));
  });
}
