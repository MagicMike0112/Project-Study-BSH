// lib/services/notification_service.dart
import 'dart:io' show Platform;
import 'dart:math'; // Kept to avoid breaking references if any

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Fixed Notification IDs
const int kLunchNotificationId = 1001;
const int kDinnerNotificationId = 1002;
const int kSnoozeNotificationId = 9999;

/// Action ID for the snooze button
const String _idSnooze = 'snooze_action';

/// 🟢 Top-level background handler (Must be outside the class)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == _idSnooze) {
    debugPrint('Snooze button clicked in background!');
    // Re-initialize service in the background isolate
    final service = NotificationService();
    await service.init();
    await service.scheduleSnooze(
      minutes: 30, 
      message: "Here is your snoozed reminder! 🍽️"
    );
  }
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    await _configureLocalTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      // Foreground action handler
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == _idSnooze) {
          scheduleSnooze(minutes: 30, message: "Here is your snoozed reminder! 🍽️");
        }
      },
      // Background action handler
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _requestPermissions();
    _initialized = true;
  }

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();
    if (Platform.isWindows) return;
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(
        alert: true, badge: true, sound: true,
      );
    }
  }

  /// 🟢 Snooze Logic
  Future<void> scheduleSnooze({
    required int minutes,
    required String message,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(Duration(minutes: minutes));

    const androidDetails = AndroidNotificationDetails(
      'snooze_channel', 
      'Snooze Reminders',
      channelDescription: 'Temporary snoozed reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      kSnoozeNotificationId,
      'Snoozed Reminder ⏰',
      message,
      scheduledDate,
      details,
      // ✅ REQUIRED for v19.5.0:
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    
    debugPrint('Snooze scheduled for: $scheduledDate');
  }

  /// 🟢 Daily Reminder Logic
  Future<void> scheduleLunchDinnerNotifications({
    TimeOfDay? lunchTime,
    TimeOfDay? dinnerTime,
    required String message,
  }) async {
    if (!_initialized) return;

    final lunch = lunchTime ?? const TimeOfDay(hour: 11, minute: 30);
    final dinner = dinnerTime ?? const TimeOfDay(hour: 17, minute: 30);

    // Notification details with Snooze button
    final androidDetails = AndroidNotificationDetails(
      'expiring_channel',
      'Expiring food reminder',
      channelDescription: 'Reminders for food that is about to expire',
      importance: Importance.max,
      priority: Priority.high,
      actions: [
        const AndroidNotificationAction(
          _idSnooze,
          'Snooze 30 min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    // Schedule Lunch
    await _plugin.zonedSchedule(
      kLunchNotificationId,
      'Smart Food Home',
      message,
      _nextInstanceOfTime(lunch, minutesBefore: 30),
      details,
      // ✅ REQUIRED for v19.5.0:
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule Dinner
    await _plugin.zonedSchedule(
      kDinnerNotificationId,
      'Smart Food Home',
      message,
      _nextInstanceOfTime(dinner, minutesBefore: 30),
      details,
      // ✅ REQUIRED for v19.5.0:
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time, {int minutesBefore = 0}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );
    if (minutesBefore != 0) {
      scheduled = scheduled.subtract(Duration(minutes: minutesBefore));
    }
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelExpiringNotifications() async {
    if (!_initialized) return;
    await _plugin.cancel(kLunchNotificationId);
    await _plugin.cancel(kDinnerNotificationId);
    await _plugin.cancel(kSnoozeNotificationId);
  }
}