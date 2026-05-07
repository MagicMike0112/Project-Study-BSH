import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

Future<void> startShowcaseOnceWhenReady({
  required BuildContext context,
  required bool hasAttempted,
  required VoidCallback markAttempted,
  required bool Function() isActiveNow,
  bool Function()? isDataReadyNow,
  required String seenPrefKey,
  required List<GlobalKey> keys,
}) async {
  final dataReadyNow = isDataReadyNow ?? () => true;
  if (hasAttempted || !isActiveNow() || !dataReadyNow()) return;
  markAttempted();

  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted || !isActiveNow() || !dataReadyNow()) return;
  final hasShown = prefs.getBool(seenPrefKey) ?? false;
  if (hasShown) return;

  for (var attempt = 0; attempt < 6; attempt++) {
    if (!context.mounted || !isActiveNow() || !dataReadyNow()) return;
    if (keys.every((k) => k.currentContext != null)) break;
    await Future.delayed(const Duration(milliseconds: 70));
  }

  if (!context.mounted || !isActiveNow() || !dataReadyNow()) return;
  if (keys.any((k) => k.currentContext == null)) return;

  try {
    ShowCaseWidget.of(context).startShowCase(keys);
    await prefs.setBool(seenPrefKey, true);
  } catch (e) {
    debugPrint('Showcase error: $e');
  }
}

class ShowcaseCoordinator {
  static Future<void> startPageShowcase({
    required BuildContext context,
    required bool hasAttempted,
    required VoidCallback markAttempted,
    required bool Function() isPageVisibleNow,
    bool Function()? isDataReadyNow,
    required String seenPrefKey,
    required List<GlobalKey> keys,
  }) {
    return startShowcaseOnceWhenReady(
      context: context,
      hasAttempted: hasAttempted,
      markAttempted: markAttempted,
      isActiveNow: isPageVisibleNow,
      isDataReadyNow: isDataReadyNow,
      seenPrefKey: seenPrefKey,
      keys: keys,
    );
  }
}

Widget wrapWithShowcase({
  required BuildContext context,
  required GlobalKey? key,
  required String title,
  required String description,
  required Widget child,
}) {
  if (key == null) return child;
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final fg = isDark ? Colors.white : const Color(0xFF111418);

  return Showcase(
    key: key,
    title: title,
    description: description,
    targetBorderRadius: BorderRadius.circular(16),
    tooltipBackgroundColor: isDark ? const Color(0xFF1E2638) : Colors.white,
    titleTextStyle: TextStyle(
      color: fg,
      fontWeight: FontWeight.w800,
      fontSize: 15,
      height: 1.2,
    ),
    descTextStyle: TextStyle(
      color: fg.withValues(alpha: 0.82),
      fontWeight: FontWeight.w500,
      fontSize: 13,
      height: 1.35,
    ),
    child: child,
  );
}
