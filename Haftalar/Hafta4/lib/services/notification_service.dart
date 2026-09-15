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

  /// Alışkanlığın hatırlatmasını (yeniden) planlar; hatırlatma kapalıysa iptal eder.
  Future<void> syncHabit(Habit habit) async {
    await init();
    final id = habit.id;
    if (id == null) return;
    await cancelHabit(id);
    final minutes = habit.reminderMinutes;
    if (minutes == null) return;

    final title = '🌱 ${habit.name}';
    const body = 'Bitkin seni bekliyor. Bugünkü alışkanlığını tamamladın mı?';

    if (habit.targetFrequency == TargetFrequency.custom) {
      // Seçili her hafta günü için ayrı haftalık tekrar.
      for (final weekday in habit.customDays) {
        await _plugin.zonedSchedule(
          id: _customId(id, weekday),
          title: title,
          body: body,
          scheduledDate: _next(minutes, weekday: weekday),
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
      scheduledDate: _next(minutes),
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

  static tz.TZDateTime _next(int minutes, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    while (!at.isAfter(now) || (weekday != null && at.weekday != weekday)) {
      at = tz.TZDateTime(
        tz.local,
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
