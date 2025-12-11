// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

const _kNotifyEnabledKey = 'notify_expiring_soon_v1';
const _kLunchTimeKey = 'notify_lunch_time_v1';   // "HH:mm"
const _kDinnerTimeKey = 'notify_dinner_time_v1'; // "HH:mm"

class SettingsPage extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 总开关：是否提醒即将过期
  bool _notifyExpiring = true;

  /// 用户填写的是“正常吃饭时间”，实际通知会在这个时间点前 30 分钟触发
  TimeOfDay? _lunchTime;
  TimeOfDay? _dinnerTime;

  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kNotifyEnabledKey) ?? true;

    TimeOfDay? parseTime(String? s) {
      if (s == null) return null;
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    setState(() {
      _notifyExpiring = enabled;
      _lunchTime = parseTime(prefs.getString(_kLunchTimeKey));
      _dinnerTime = parseTime(prefs.getString(_kDinnerTimeKey));
      _loadingPrefs = false;
    });
  }

  /// 按当前设置（开关 + 午/晚饭时间）安排通知
  Future<void> _scheduleNotificationsForCurrentSettings() async {
    if (!_notifyExpiring) return;

    await NotificationService().scheduleLunchDinnerNotifications(
      lunchTime: _lunchTime,
      dinnerTime: _dinnerTime,
      message:
          'Some of your ingredients are expiring soon. Check Smart Food Home 🍽️',
    );
  }

  Future<void> _setNotifyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifyEnabledKey, value);
    setState(() => _notifyExpiring = value);

    if (value) {
      // 开启：根据当前午/晚饭时间安排通知
      await _scheduleNotificationsForCurrentSettings();
    } else {
      // 关闭：取消所有过期提醒
      await NotificationService().cancelExpiringNotifications();
    }
  }

  Future<void> _pickTime({required bool isLunch}) async {
    final initial = isLunch
        ? (_lunchTime ?? const TimeOfDay(hour: 12, minute: 0))
        : (_dinnerTime ?? const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final prefs = await SharedPreferences.getInstance();

    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    setState(() {
      if (isLunch) {
        _lunchTime = picked;
        prefs.setString(_kLunchTimeKey, fmt(picked));
      } else {
        _dinnerTime = picked;
        prefs.setString(_kDinnerTimeKey, fmt(picked));
      }
    });

    // 如果开关是开的，更新排程
    if (_notifyExpiring) {
      await _scheduleNotificationsForCurrentSettings();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Saved. New reminder time will apply to future notifications.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _resetTimesToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLunchTimeKey);
    await prefs.remove(_kDinnerTimeKey);
    setState(() {
      _lunchTime = null;
      _dinnerTime = null;
    });

    // 恢复默认时间（11:30 / 17:30）并重排通知
    if (_notifyExpiring) {
      await _scheduleNotificationsForCurrentSettings();
    }
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(time, alwaysUse24HourFormat: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Notifications Section =====
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Remind me about expiring food'),
                  subtitle: const Text(
                    'Get a reminder around lunch and dinner time.',
                  ),
                  value: _notifyExpiring,
                  onChanged: (val) => _setNotifyEnabled(val),
                ),
                if (_notifyExpiring) const Divider(height: 0),

                if (_notifyExpiring)
                  ListTile(
                    title: const Text('Usual lunch time'),
                    subtitle: Text(
                      _lunchTime != null
                          ? 'Notify 30 min before ${_formatTime(context, _lunchTime!)}'
                          : 'Default reminder at 11:30',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickTime(isLunch: true),
                  ),

                if (_notifyExpiring) const Divider(height: 0),

                if (_notifyExpiring)
                  ListTile(
                    title: const Text('Usual dinner time'),
                    subtitle: Text(
                      _dinnerTime != null
                          ? 'Notify 30 min before ${_formatTime(context, _dinnerTime!)}'
                          : 'Default reminder at 17:30',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickTime(isLunch: false),
                  ),

                if (_notifyExpiring)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetTimesToDefault,
                      child: const Text('Reset to default times'),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ===== Account Section =====
          const Text(
            'Account',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: widget.isLoggedIn
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You are logged in.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: widget.onLogout,
                          child: const Text('Log out'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No account connected',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Log in to sync your data and connect partners like Home Connect or PAYBACK later.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: widget.onLogin,
                          child: const Text('Log in / Sign up'),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
