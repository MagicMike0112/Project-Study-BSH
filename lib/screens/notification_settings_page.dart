// lib/screens/notification_settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/inventory_repository.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _notifyMealReminders = true;
  bool _notifyThreeDayExpiry = true;
  TimeOfDay? _lunchTime;
  TimeOfDay? _dinnerTime;

  bool _loadingPrefs = true;
  bool _saving = false;
  bool _statusLoading = false;
  bool _permissionGranted = false;
  bool _hasMealScheduled = false;
  bool _hasThreeDayScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
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

    setState(() {
      _notifyMealReminders = mealEnabled;
      _notifyThreeDayExpiry = threeDayEnabled;
      _lunchTime = parseTime(prefs.getString(kLunchTimePrefKey));
      _dinnerTime = parseTime(prefs.getString(kDinnerTimePrefKey));
      _loadingPrefs = false;
    });

    await _refreshNotificationStatus();
  }

  Future<bool> _ensurePermissionOrToast() async {
    final l10n = AppLocalizations.of(context);
    final granted = await NotificationService().requestPermissionsIfNeeded();
    if (granted) return true;
    if (mounted) {
      setState(() => _permissionGranted = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.notificationPermissionBlocked ??
                'Notification permission is blocked in system settings.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
    return false;
  }

  Future<void> _scheduleMealRemindersIfEnabled() async {
    final l10n = AppLocalizations.of(context);
    final service = NotificationService();
    if (!_notifyMealReminders) {
      await service.cancelExpiringNotifications();
      return;
    }

    await service.scheduleLunchDinnerNotifications(
      lunchTime: _lunchTime,
      dinnerTime: _dinnerTime,
      message: l10n?.notificationMealReminderMessage ??
          'Some of your ingredients are expiring soon. Check Smart Food Home.',
    );
  }

  Future<void> _scheduleThreeDayRemindersIfEnabled() async {
    final service = NotificationService();
    final repo = context.read<InventoryRepository>();
    if (!_notifyThreeDayExpiry) {
      await service.cancelThreeDayExpiryReminders();
      return;
    }

    await service.scheduleThreeDayExpiryReminders(items: repo.getActiveItems());
  }

  Future<void> _setMealReminderEnabled(bool value) async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      final granted = await _ensurePermissionOrToast();
      if (!granted) {
        await prefs.setBool(kMealReminderEnabledPrefKey, false);
        if (mounted) {
          setState(() {
            _notifyMealReminders = false;
            _saving = false;
          });
        }
        return;
      }
    }

    await prefs.setBool(kMealReminderEnabledPrefKey, value);
    if (mounted) setState(() => _notifyMealReminders = value);
    await _scheduleMealRemindersIfEnabled();
    await _refreshNotificationStatus();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _setThreeDayReminderEnabled(bool value) async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      final granted = await _ensurePermissionOrToast();
      if (!granted) {
        await prefs.setBool(kThreeDayReminderEnabledPrefKey, false);
        if (mounted) {
          setState(() {
            _notifyThreeDayExpiry = false;
            _saving = false;
          });
        }
        return;
      }
    }

    await prefs.setBool(kThreeDayReminderEnabledPrefKey, value);
    if (mounted) setState(() => _notifyThreeDayExpiry = value);
    await _scheduleThreeDayRemindersIfEnabled();
    await _refreshNotificationStatus();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickTime({required bool isLunch}) async {
    final l10n = AppLocalizations.of(context);
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

    if (isLunch) {
      await prefs.setString(kLunchTimePrefKey, fmt(picked));
    } else {
      await prefs.setString(kDinnerTimePrefKey, fmt(picked));
    }

    setState(() {
      if (isLunch) {
        _lunchTime = picked;
      } else {
        _dinnerTime = picked;
      }
    });

    if (_notifyMealReminders) {
      await _scheduleMealRemindersIfEnabled();
      await _refreshNotificationStatus();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.notificationSavedFutureApply ??
                'Saved. New reminder time will apply to future notifications.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetTimesToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kLunchTimePrefKey);
    await prefs.remove(kDinnerTimePrefKey);
    setState(() {
      _lunchTime = null;
      _dinnerTime = null;
    });

    if (_notifyMealReminders) {
      await _scheduleMealRemindersIfEnabled();
    }

    await _refreshNotificationStatus();
  }

  Future<void> _refreshNotificationStatus() async {
    if (!mounted) return;
    setState(() => _statusLoading = true);

    final service = NotificationService();
    final permissionGranted = await service.areNotificationsEnabled();
    final hasScheduledReminders =
        await service.hasExpiringNotificationsScheduled();
    final hasThreeDayReminders =
        await service.hasThreeDayExpiryRemindersScheduled();

    if (!mounted) return;
    setState(() {
      _permissionGranted = permissionGranted;
      _hasMealScheduled = hasScheduledReminders;
      _hasThreeDayScheduled = hasThreeDayReminders;
      _statusLoading = false;
    });
  }

  Future<void> _sendTestNotification() async {
    final l10n = AppLocalizations.of(context);
    final granted = await NotificationService().requestPermissionsIfNeeded();
    if (!granted) {
      if (mounted) {
        setState(() => _permissionGranted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.notificationEnablePermissionFirst ??
                  'Please enable notification permission first.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    await NotificationService().showTestNotification(
      message: l10n?.notificationTestMessage ??
          'This is a test expiry reminder from Smart Food Home.',
    );
    await _refreshNotificationStatus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.notificationTestSent ?? 'Test notification sent.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(time, alwaysUse24HourFormat: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loadingPrefs) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n?.accountNotificationsTitle ?? 'Notifications')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final mutedStrong = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.accountNotificationsTitle ?? 'Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
    
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
                        child: Text(
                          l10n?.notificationThreeDayExpiryTitle ?? '3-day expiry alerts',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _notifyThreeDayExpiry,
                        onChanged: _saving ? null : _setThreeDayReminderEnabled,
                      ),
                    ],
                  ),
                  Text(
                    l10n?.notificationThreeDayExpiryDesc ??
                        'One-time reminder when an item is 3 days from expiry.',
                    style: textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n?.notificationMealTimeTitle ?? 'Meal-time reminders',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _notifyMealReminders,
                        onChanged: _saving ? null : _setMealReminderEnabled,
                      ),
                    ],
                  ),
                  Text(
                    l10n?.notificationMealTimeDesc ??
                        'Two daily reminders at your lunch and dinner time.',
                    style: textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _permissionGranted
                            ? Icons.verified_rounded
                            : Icons.error_outline_rounded,
                        size: 16,
                        color: _permissionGranted ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _permissionGranted
                            ? (l10n?.notificationPermissionAllowed ??
                                'System notification permission: allowed')
                            : (l10n?.notificationPermissionBlockedStatus ??
                                'System notification permission: blocked'),
                        style: textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        (_hasMealScheduled || _hasThreeDayScheduled)
                            ? Icons.schedule_rounded
                            : Icons.schedule_outlined,
                        size: 16,
                        color: (_hasMealScheduled || _hasThreeDayScheduled)
                            ? Colors.blue
                            : muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n?.notificationStatusCombined(
                                _hasMealScheduled
                                    ? (l10n.notificationStatusScheduled)
                                    : (l10n.notificationStatusOff),
                                _hasThreeDayScheduled
                                    ? (l10n.notificationStatusScheduled)
                                    : (l10n.notificationStatusOff),
                              ) ??
                              'Meal reminders: ${_hasMealScheduled ? 'scheduled' : 'off'} | 3-day alerts: ${_hasThreeDayScheduled ? 'scheduled' : 'off'}',
                          style: textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                      if (_statusLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                          l10n?.notificationMealTimesTitle ?? 'Meal times',
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: mutedStrong,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n?.notificationMealTimesHint ??
                              "We'll notify you about expiring items at these times.",
                          style: textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _TimeRow(
                          icon: Icons.lunch_dining_outlined,
                          label: l10n?.notificationLunchLabel ?? 'Usual lunch time',
                          value: _lunchTime != null
                              ? _formatTime(context, _lunchTime!)
                              : (l10n?.notificationDefaultLunchTime ?? '11:30 (default)'),
                          onTap: () => _pickTime(isLunch: true),
                        ),

                        const SizedBox(height: 6),

                        _TimeRow(
                          icon: Icons.dinner_dining_outlined,
                          label: l10n?.notificationDinnerLabel ?? 'Usual dinner time',
                          value: _dinnerTime != null
                              ? _formatTime(context, _dinnerTime!)
                              : (l10n?.notificationDefaultDinnerTime ?? '17:30 (default)'),
                          onTap: () => _pickTime(isLunch: false),
                        ),

                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetTimesToDefault,
                            child: Text(l10n?.notificationResetDefaults ?? 'Reset to defaults'),
                          ),
                        ),
                      ],
                    ),
                    crossFadeState: _notifyMealReminders
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _sendTestNotification,
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                      label: Text(l10n?.notificationSendTestNow ?? 'Send test now'),
                    ),
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

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
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
              ),
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
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
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

