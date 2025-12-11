// lib/services/notification_service.dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb; // 👈 新增：判断是不是 Web
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 固定两个 ID，分别给午饭 / 晚饭提醒
const int kLunchNotificationId = 1001;
const int kDinnerNotificationId = 1002;

/// 全局单例调用：NotificationService()
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 在 main() 里调用一次：
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   if (!kIsWeb) await NotificationService().init();
  Future<void> init() async {
    if (_initialized) return;

    // Web 端不支持本地通知插件，直接 no-op，避免白屏 / 异常
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // 1) 配置时区（zonedSchedule 必须）
    await _configureLocalTimeZone();

    // 2) 初始化通知插件
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      // 这里先不请求权限，下面再单独请求
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);

    // 3) 请求权限（Android / iOS / macOS 各自处理）
    await _requestPermissions();

    _initialized = true;
  }

  /// 配置本地时区（适配 flutter_timezone 5.x）
  Future<void> _configureLocalTimeZone() async {
    // Web 上直接跳过
    if (kIsWeb) return;

    tz.initializeTimeZones();

    // 真正在手机上跑的时候这里不会是 Windows，这个分支只是避免你在
    // Windows 桌面上跑原生示例时踩坑；保留也没问题。
    if (Platform.isWindows) {
      return;
    }

    // flutter_timezone 5.x 返回的是 TimezoneInfo，不再是 String
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    // 用 tz 数据库里的 identifier，例如 "Europe/Berlin"
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
  }

  Future<void> _requestPermissions() async {
    // Web 上没有本地通知权限这一说
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Android 13+ 通知权限
      await androidImpl?.requestNotificationsPermission();
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final macImpl = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();

      await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      await macImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// 计算“下一次某个时间点”的 TZDateTime（按天循环）
  tz.TZDateTime _nextInstanceOfTime(
    TimeOfDay time, {
    int minutesBefore = 0,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // 提前 minutesBefore 分钟
    if (minutesBefore != 0) {
      scheduled = scheduled.subtract(Duration(minutes: minutesBefore));
    }

    // 如果今天这个时间已经过去了，推到明天
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// 示例：根据午饭/晚饭时间安排两个每日通知
  /// （以后你在 Today 页算好 expiring 的数量，传一个 message 进来即可）
  Future<void> scheduleLunchDinnerNotifications({
    TimeOfDay? lunchTime,
    TimeOfDay? dinnerTime,
    required String message,
  }) async {
    if (!_initialized) return;

    // 默认 11:30 / 17:30
    final lunch = lunchTime ?? const TimeOfDay(hour: 11, minute: 30);
    final dinner = dinnerTime ?? const TimeOfDay(hour: 17, minute: 30);

    final androidDetails = AndroidNotificationDetails(
      'expiring_channel', // channel id
      'Expiring food reminder', // channel name
      channelDescription: 'Reminders for food that is about to expire',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    // 午饭前 30 分钟
    final lunchTimeTz =
        _nextInstanceOfTime(lunch, minutesBefore: 30); // 11:00 或用户时间-30min

    await _plugin.zonedSchedule(
      kLunchNotificationId,
      'Smart Food Home',
      message,
      lunchTimeTz,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 每天重复
    );

    // 晚饭前 30 分钟
    final dinnerTimeTz =
        _nextInstanceOfTime(dinner, minutesBefore: 30); // 17:00 或用户时间-30min

    await _plugin.zonedSchedule(
      kDinnerNotificationId,
      'Smart Food Home',
      message,
      dinnerTimeTz,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Settings 里调用的：关闭和过期相关的提醒
  Future<void> cancelExpiringNotifications() async {
    if (!_initialized) return;
    await _plugin.cancel(kLunchNotificationId);
    await _plugin.cancel(kDinnerNotificationId);
  }

  /// 备用：取消所有本地通知
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
