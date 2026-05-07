import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocale {
  static const _prefKey = 'app_locale_code_v1';

  static const _supported = {'en', 'zh', 'de'};

  static String normalize(String? code) {
    final raw = (code ?? '').trim().toLowerCase();
    if (raw.isEmpty) return 'en';
    final base = raw.split('-').first;
    return _supported.contains(base) ? base : 'en';
  }

  static String fromContext(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return normalize(locale?.languageCode);
  }

  static Future<String> fromPreferencesOrSystem() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.isNotEmpty) {
        return normalize(saved);
      }
    } catch (_) {}
    return normalize(PlatformDispatcher.instance.locale.languageCode);
  }
}
