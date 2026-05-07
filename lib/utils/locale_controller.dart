import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleCodeKey = 'app_locale_code_v1';

class LocaleController extends ChangeNotifier {
  static const Set<String> _supported = {'en', 'zh', 'de'};
  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCode = prefs.getString(_kLocaleCodeKey);
    final code = rawCode?.trim().toLowerCase();
    if (code != null && code.isNotEmpty && _supported.contains(code)) {
      _locale = Locale(code);
    } else {
      _locale = null;
      if (rawCode != null && rawCode.isNotEmpty) {
        await prefs.remove(_kLocaleCodeKey);
      }
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    final nextCode = locale?.languageCode;
    final currentCode = _locale?.languageCode;
    if (nextCode == currentCode) return;

    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (nextCode == null || nextCode.isEmpty) {
      await prefs.remove(_kLocaleCodeKey);
    } else {
      await prefs.setString(_kLocaleCodeKey, nextCode);
    }
  }
}
