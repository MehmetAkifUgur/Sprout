import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/habit.dart';
import '../domain/habit_schedule.dart';

/// Günlük hatırlatma bildirimleri. Her alışkanlık kendi id'si ile planlanır.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'habit_reminders',
      'Alışkanlık hatırlatmaları',
      channelDescription: 'Bitkini sulamayı unutma hatırlatmaları',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      debugPrint('Saat dilimi alınamadı, UTC kullanılıyor: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Alışkanlığın hatırlatmasını (yeniden) planlar; hatırlatma kapalıysa ya da
  /// alışkanlık tatildeyse iptal eder. [notBefore] verilirse ilk bildirim o
  /// günden önce çalmaz (ör. bugün zaten tamamlandıysa yarından başlar).
  Future<void> syncHabit(Habit habit, {DateTime? notBefore}) async {
    await init();
    final id = habit.id;
    if (id == null) return;
    await cancelHabit(id);
    final minutes = habit.reminderMinutes;
    if (minutes == null || habit.isPaused) return;
    final now = tz.TZDateTime.now(tz.local);

    final title = '🌱 ${habit.name}';
    const body = 'Bitkin seni bekliyor. Bugünkü alışkanlığını tamamladın mı?';

    if (habit.targetFrequency == TargetFrequency.custom) {
      // Seçili her hafta günü için ayrı haftalık tekrar.
      for (final weekday in habit.customDays) {
        await _plugin.zonedSchedule(
          id: _customId(id, weekday),
          title: title,
          body: body,
          scheduledDate: nextReminder(
            now,
            minutes,
            weekday: weekday,
            notBefore: notBefore,
          ),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return;
    }

    await _plugin.zonedSchedule(
      id: _customId(id, 0),
      title: title,
      body: body,
      scheduledDate: nextReminder(now, minutes, notBefore: notBefore),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelHabit(int habitId) async {
    await init();
    // 0: günlük/haftalık, 1–7: özel günler.
    for (var weekday = 0; weekday <= DateTime.sunday; weekday++) {
      await _plugin.cancel(id: _customId(habitId, weekday));
    }
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  static int _customId(int habitId, int slot) => habitId * 10 + slot;

  /// [now]'dan sonraki, [minutes] saatindeki ilk an. [weekday] verilirse o hafta
  /// gününe, [notBefore] verilirse o gün ya da sonrasına denk gelir.
  @visibleForTesting
  static tz.TZDateTime nextReminder(
    tz.TZDateTime now,
    int minutes, {
    int? weekday,
    DateTime? notBefore,
  }) {
    var at = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    bool early(tz.TZDateTime t) =>
        notBefore != null &&
        DateTime(
          t.year,
          t.month,
          t.day,
        ).isBefore(DateTime(notBefore.year, notBefore.month, notBefore.day));
    while (!at.isAfter(now) ||
        early(at) ||
        (weekday != null && at.weekday != weekday)) {
      at = tz.TZDateTime(
        now.location,
        at.year,
        at.month,
        at.day + 1,
        at.hour,
        at.minute,
      );
    }
    return at;
  }
}
