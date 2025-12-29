// lib/screens/notification_settings_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

const _kNotifyEnabledKey = 'notify_expiring_soon_v1';
const _kLunchTimeKey = 'notify_lunch_time_v1';   // "HH:mm"
const _kDinnerTimeKey = 'notify_dinner_time_v1'; // "HH:mm"

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _notifyExpiring = true;
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

  Future<void> _scheduleNotificationsForCurrentSettings() async {
    if (!_notifyExpiring) return;

    // 🟢 核心修改：调用 Service 时传入当前选定的时间
    await NotificationService().scheduleLunchDinnerNotifications(
      lunchTime: _lunchTime,
      dinnerTime: _dinnerTime,
      message: 'Some of your ingredients are expiring soon. Check Smart Food Home 🍽️',
    );
  }

  Future<void> _setNotifyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifyEnabledKey, value);
    setState(() => _notifyExpiring = value);

    if (value) {
      await _scheduleNotificationsForCurrentSettings();
    } else {
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

    if (_notifyExpiring) {
      await _scheduleNotificationsForCurrentSettings();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saved. New reminder time will apply to future notifications.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetTimesToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLunchTimeKey);
    await prefs.remove(_kDinnerTimeKey);
    setState(() {
      _lunchTime = null;
      _dinnerTime = null;
    });

    if (_notifyExpiring) {
      await _scheduleNotificationsForCurrentSettings();
    }
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(time, alwaysUse24HourFormat: true);
  }

  String _currentScheduleSummary(BuildContext context) {
    final lunchText = _lunchTime != null
        ? 'before ${_formatTime(context, _lunchTime!)}'
        : 'before lunch';
    final dinnerText = _dinnerTime != null
        ? 'before ${_formatTime(context, _dinnerTime!)}'
        : 'before dinner';
    return 'We’ll remind you ~30 min $lunchText and $dinnerText.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Smart reminders',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Get a gentle nudge before your usual meals when ingredients are close to expiring.',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expiry reminders',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _notifyExpiring
                                  ? _currentScheduleSummary(context)
                                  : 'Turn this on to receive daily reminders.',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _notifyExpiring,
                        onChanged: _setNotifyEnabled,
                      ),
                    ],
                  ),

                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Meal times',
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We’ll notify you about expiring items ~30 minutes before these times.',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),

                        _TimeRow(
                          icon: Icons.lunch_dining_outlined,
                          label: 'Usual lunch time',
                          value: _lunchTime != null
                              ? _formatTime(context, _lunchTime!)
                              : '11:30 (default)',
                          onTap: () => _pickTime(isLunch: true),
                        ),

                        const SizedBox(height: 6),

                        _TimeRow(
                          icon: Icons.dinner_dining_outlined,
                          label: 'Usual dinner time',
                          value: _dinnerTime != null
                              ? _formatTime(context, _dinnerTime!)
                              : '17:30 (default)',
                          onTap: () => _pickTime(isLunch: false),
                        ),

                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetTimesToDefault,
                            child: const Text('Reset to defaults'),
                          ),
                        ),
                      ],
                    ),
                    crossFadeState: _notifyExpiring
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
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

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[100],
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}