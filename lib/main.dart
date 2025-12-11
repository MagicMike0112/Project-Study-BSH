// lib/main.dart
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_root.dart';
import 'screens/reset_password_page.dart';
import 'services/notification_service.dart';

class BshColors {
  static const primary = flutter.Color(0xFF004A77);
  static const secondary = flutter.Color(0xFF50738A);

  static const surface = flutter.Color(0xFFF6F8FA);

  static const eco = flutter.Color(0xFF4B8F6F);
  static const warning = flutter.Color(0xFFE0A100);
  static const danger = flutter.Color(0xFFB93A3A);

  static const text = flutter.Color(0xFF1A1A1A);
}

// 全局 navigatorKey，用来在收到 passwordRecovery / signup 事件时跳页
final flutter.GlobalKey<flutter.NavigatorState> rootNavigatorKey =
    flutter.GlobalKey<flutter.NavigatorState>();

Future<void> main() async {
  flutter.WidgetsFlutterBinding.ensureInitialized();

  // 1) Supabase 初始化
  await Supabase.initialize(
    url: 'https://avsyxlgfqnrknvvbjxul.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2c3l4bGdmcW5ya252dmJqeHVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzNTk2MjcsImV4cCI6MjA4MDkzNTYyN30.M7FfDZzjYvCt0hSz0W508oSGmzw7tcZ9E5vGyQlnCKY',
  );

  final supabase = Supabase.instance.client;

  // 2) Web 下：处理带 code / hash 的回调 URL（PKCE / implicit）
  if (kIsWeb) {
    final uri = Uri.base;

    // --- PKCE: https://bshpwa.vercel.app/?code=...&type=recovery ---
    final hasPkceCode = uri.queryParameters['code'] != null;

    // --- 旧的 implicit 流程: https://.../#access_token=...&type=recovery ---
    final hasImplicitHash =
        uri.fragment.isNotEmpty && uri.fragment.contains('access_token');

    if (hasPkceCode || hasImplicitHash) {
      try {
        // 对于 implicit，getSessionFromUrl 也能自己从 fragment 里解析
        await supabase.auth.getSessionFromUrl(uri);
      } catch (e) {
        // 这里你可以打印 log，暂时忽略也行
        // print('getSessionFromUrl error: $e');
      }
    }
  }

  // 3) 监听 Auth 状态变化：处理密码重置 / 验证邮件
  supabase.auth.onAuthStateChange.listen((data) {
    final event = data.event;

    if (event == AuthChangeEvent.passwordRecovery) {
      // 用户通过 reset password link 回来了
      rootNavigatorKey.currentState?.push(
        flutter.MaterialPageRoute(
          builder: (_) => const ResetPasswordPage(),
        ),
      );
    }

    // 如果以后要做 “邮箱验证成功提示”，可以在这里处理 signup:
    // if (event == AuthChangeEvent.signedIn) { ... }
  });

  // 4) 本地通知只在原生端初始化，Web 要跳过
  if (!kIsWeb) {
    await NotificationService().init();
  }

  // 5) 跑 App
  flutter.runApp(const SmartFoodApp());
}

class SmartFoodApp extends flutter.StatelessWidget {
  const SmartFoodApp({super.key});

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Smart Food Home',
      debugShowCheckedModeBanner: false,
      theme: flutter.ThemeData(
        useMaterial3: true,
        colorSchemeSeed: BshColors.primary,
        scaffoldBackgroundColor: BshColors.surface,
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: BshColors.text,
          displayColor: BshColors.text,
        ),
        appBarTheme: const flutter.AppBarTheme(
          backgroundColor: flutter.Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: flutter.TextStyle(
            color: BshColors.primary,
            fontSize: 20,
            fontWeight: flutter.FontWeight.bold,
          ),
          iconTheme: flutter.IconThemeData(color: BshColors.primary),
        ),
      ),
      home: const AuthRoot(),
    );
  }
}
