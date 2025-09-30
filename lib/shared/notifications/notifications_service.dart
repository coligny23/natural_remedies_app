// lib/shared/notifications/notifications_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationsService {
  static final NotificationsService _i = NotificationsService._internal();
  factory NotificationsService() => _i;
  NotificationsService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited || kIsWeb) return;

    // 1) Initialize plugin (Android + iOS)
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const init = InitializationSettings(android: initAndroid, iOS: initDarwin);
    await _plugin.initialize(init);

    // 2) Init timezone database (needed for zonedSchedule)
    tz.initializeTimeZones();

    // 3) Android 13+ runtime permission for posting notifications
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Correct method name in recent versions:
      await android?.requestNotificationsPermission(); // returns bool?
    }

    _inited = true;
  }

  /// Schedule a *daily* reminder at [time] (local device time).
  Future<void> scheduleDaily(
    int id,
    TimeOfDay time, {
    String? title,
    String? body,
  }) async {
    if (kIsWeb) return; // skip on web
    await init();

    const android = AndroidNotificationDetails(
      'daily_study_channel',
      'Daily Study',
      channelDescription: 'Daily reminder to continue learning',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    // Compute the next occurrence of the given hour/minute in the local TZ
    final next = _nextDailyInstance(time);

    // Cancel any previous schedule with the same id to avoid duplicates
    await _plugin.cancel(id);

    // New API: use androidScheduleMode + matchDateTimeComponents (daily at time)
    await _plugin.zonedSchedule(
      id,
      title ?? 'Keep learning',
      body ?? 'Take a minute to read one remedy today.',
      next,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: null,
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id);
  }

  // Build the next local TZ time for the given hour/min
  tz.TZDateTime _nextDailyInstance(TimeOfDay t) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// Simple TimeOfDay helper for non-Widget code
class TimeOfDay {
  final int hour, minute;
  const TimeOfDay({required this.hour, required this.minute});
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
