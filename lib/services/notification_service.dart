// lib/services/notification_service.dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/food_item.dart';

const String kLegacyNotifyEnabledPrefKey = 'notify_expiring_soon_v1';
const String kMealReminderEnabledPrefKey = 'notify_meal_reminders_v1';
const String kThreeDayReminderEnabledPrefKey = 'notify_3day_expiry_v1';
const String kLunchTimePrefKey = 'notify_lunch_time_v1';   // "HH:mm"
const String kDinnerTimePrefKey = 'notify_dinner_time_v1'; // "HH:mm"

/// Fixed Notification IDs
const int kLunchNotificationId = 1001;
const int kDinnerNotificationId = 1002;
const int kSnoozeNotificationId = 9999;
const int kTestNotificationId = 1003;
const int kScheduledTestNotificationId = 1004;
const int _kExpirySoonBaseId = 20000;
const int _kExpirySoonIdSpan = 900000;
const String _kExpirySoonPayloadPrefix = 'expiry_soon_3d:';

/// Action ID for the snooze button
const String _idSnooze = 'snooze_action';

// NOTE: legacy comment cleaned.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == _idSnooze) {
    debugPrint('Snooze button clicked in background!');
    // Re-initialize service in the background isolate
    final service = NotificationService();
    await service.init();
    await service.scheduleSnooze(
      minutes: 30, 
      message: 'Reminder snoozed for 30 minutes.'
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
          scheduleSnooze(
            minutes: 30,
            message: 'Reminder snoozed for 30 minutes.',
          );
        }
      },
      // Background action handler
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _requestPermissionsInternal();
    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await init();
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

  Future<bool> _requestPermissionsInternal() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final alreadyEnabled = await androidImpl?.areNotificationsEnabled();
      if (alreadyEnabled == true) return true;
      final granted = await androidImpl?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final darwinGranted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return darwinGranted ?? false;
    }

    return true;
  }

  Future<bool> requestPermissionsIfNeeded() async {
    if (kIsWeb) return false;
    await _ensureInitialized();
    return _requestPermissionsInternal();
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    await _ensureInitialized();

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidImpl?.areNotificationsEnabled() ?? false;
    }

    // The plugin does not expose a reliable query API for all Darwin variants.
    return true;
  }

  // NOTE: legacy comment cleaned.
  Future<void> scheduleSnooze({
    required int minutes,
    required String message,
  }) async {
    if (kIsWeb) return;
    await _ensureInitialized();
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

    await _zonedScheduleWithFallback(
      kSnoozeNotificationId,
      'Smart Food Home',
      message,
      scheduledDate,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    
    debugPrint('Snooze scheduled for: $scheduledDate');
  }

  // NOTE: legacy comment cleaned.
  Future<void> scheduleLunchDinnerNotifications({
    TimeOfDay? lunchTime,
    TimeOfDay? dinnerTime,
    required String message,
  }) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    if (!_initialized) return;
    final permissionGranted = await requestPermissionsIfNeeded();
    if (!permissionGranted) return;

    final lunch = lunchTime ?? const TimeOfDay(hour: 11, minute: 30);
    final dinner = dinnerTime ?? const TimeOfDay(hour: 17, minute: 30);

    await _plugin.cancel(kLunchNotificationId);
    await _plugin.cancel(kDinnerNotificationId);

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
    await _zonedScheduleWithFallback(
      kLunchNotificationId,
      'Smart Food Home',
      message,
      _nextInstanceOfTime(lunch),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule Dinner
    await _zonedScheduleWithFallback(
      kDinnerNotificationId,
      'Smart Food Home',
      message,
      _nextInstanceOfTime(dinner),
      details,
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
    if (kIsWeb) return;
    await _ensureInitialized();
    await _plugin.cancel(kLunchNotificationId);
    await _plugin.cancel(kDinnerNotificationId);
    await _plugin.cancel(kSnoozeNotificationId);
  }

  Future<bool> hasExpiringNotificationsScheduled() async {
    if (kIsWeb) return false;
    await _ensureInitialized();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any(
      (req) => req.id == kLunchNotificationId || req.id == kDinnerNotificationId,
    );
  }

  Future<void> showTestNotification({
    String message = 'Test notification from Smart Food Home.',
  }) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    final permissionGranted = await requestPermissionsIfNeeded();
    if (!permissionGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'expiring_channel',
      'Expiring food reminder',
      channelDescription: 'Reminders for food that is about to expire',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(
      kTestNotificationId,
      'Smart Food Home',
      message,
      details,
    );
  }

  Future<void> scheduleTestNotificationInOneMinute() async {
    if (kIsWeb) return;
    await _ensureInitialized();
    final permissionGranted = await requestPermissionsIfNeeded();
    if (!permissionGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'expiring_channel',
      'Expiring food reminder',
      channelDescription: 'Reminders for food that is about to expire',
      importance: Importance.max,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.cancel(kScheduledTestNotificationId);
    final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    await _zonedScheduleWithFallback(
      kScheduledTestNotificationId,
      'Smart Food Home',
      'Scheduled test notification (1 minute).',
      when,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleThreeDayExpiryReminders({
    required List<FoodItem> items,
    TimeOfDay remindAt = const TimeOfDay(hour: 9, minute: 0),
  }) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    final permissionGranted = await requestPermissionsIfNeeded();
    if (!permissionGranted) return;

    await cancelThreeDayExpiryReminders();

    final now = tz.TZDateTime.now(tz.local);

    const androidDetails = AndroidNotificationDetails(
      'expiring_soon_channel',
      '3-day expiry reminders',
      channelDescription: 'Alerts when items are 3 days away from expiry',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    for (final item in items) {
      if (item.status != FoodStatus.good || item.predictedExpiry == null) continue;

      final expiry = item.predictedExpiry!;
      final reminderDate = DateTime(
        expiry.year,
        expiry.month,
        expiry.day,
      ).subtract(const Duration(days: 3));

      final scheduleAt = tz.TZDateTime(
        tz.local,
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        remindAt.hour,
        remindAt.minute,
      );

      if (!scheduleAt.isAfter(now)) continue;

      final id = _notificationIdForItem(item.id);
      final payload = '$_kExpirySoonPayloadPrefix${item.id}';
      final mm = expiry.month.toString().padLeft(2, '0');
      final dd = expiry.day.toString().padLeft(2, '0');

      await _zonedScheduleWithFallback(
        id,
        'Expiring in 3 days',
        '${item.name} is expected to expire on $mm/$dd.',
        scheduleAt,
        details,
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelThreeDayExpiryReminders() async {
    if (kIsWeb) return;
    await _ensureInitialized();
    final pending = await _plugin.pendingNotificationRequests();
    for (final req in pending) {
      if ((req.payload ?? '').startsWith(_kExpirySoonPayloadPrefix)) {
        await _plugin.cancel(req.id);
      }
    }
  }

  Future<bool> hasThreeDayExpiryRemindersScheduled() async {
    if (kIsWeb) return false;
    await _ensureInitialized();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any(
      (req) => (req.payload ?? '').startsWith(_kExpirySoonPayloadPrefix),
    );
  }

  int _notificationIdForItem(String itemId) {
    var hash = 0;
    for (final c in itemId.codeUnits) {
      hash = ((hash * 31) + c) % _kExpirySoonIdSpan;
    }
    return _kExpirySoonBaseId + hash;
  }

  Future<void> _zonedScheduleWithFallback(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            uiLocalNotificationDateInterpretation,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            uiLocalNotificationDateInterpretation,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
    }
  }

  Future<void> syncSchedulesFromPreferences({
    required List<FoodItem> activeItems,
  }) async {
    if (kIsWeb) return;
    await _ensureInitialized();

    final permissionEnabled = await areNotificationsEnabled();
    if (!permissionEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    final legacyEnabled = prefs.getBool(kLegacyNotifyEnabledPrefKey);
    final mealEnabled =
        prefs.getBool(kMealReminderEnabledPrefKey) ?? legacyEnabled ?? true;
    final threeDayEnabled =
        prefs.getBool(kThreeDayReminderEnabledPrefKey) ?? legacyEnabled ?? true;

    TimeOfDay? parseTime(String? s) {
      if (s == null) return null;
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    final lunchTime = parseTime(prefs.getString(kLunchTimePrefKey));
    final dinnerTime = parseTime(prefs.getString(kDinnerTimePrefKey));

    if (mealEnabled) {
      await scheduleLunchDinnerNotifications(
        lunchTime: lunchTime,
        dinnerTime: dinnerTime,
        message: 'Some of your ingredients are expiring soon. Check Smart Food Home.',
      );
    } else {
      await cancelExpiringNotifications();
    }

    if (threeDayEnabled) {
      await scheduleThreeDayExpiryReminders(items: activeItems);
    } else {
      await cancelThreeDayExpiryReminders();
    }
  }
}

