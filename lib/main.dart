// lib/main.dart
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'; // 🟢 Added for SystemChrome
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_root.dart';
import 'services/notification_service.dart';

class BshColors {
  static const primary = flutter.Color(0xFF004A77); // BSH Blue
  static const secondary = flutter.Color(0xFF50738A);
  static const surface = flutter.Color(0xFFF6F8FA); // Light Grey-Blue bg
  static const eco = flutter.Color(0xFF4B8F6F);
  static const warning = flutter.Color(0xFFE0A100);
  static const danger = flutter.Color(0xFFB93A3A);
  static const text = flutter.Color(0xFF1A1A1A);
}

Future<void> main() async {
  flutter.WidgetsFlutterBinding.ensureInitialized();

  // 🟢 1. 设置沉浸式状态栏 (透明背景，黑色图标)
  // 这样 App 一启动就是全屏通透的感觉
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: flutter.Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS
  ));

  // 🟢 2. 锁定竖屏 (防止布局在横屏下错乱)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 3. Supabase 初始化
  // 注意：在生产环境中，建议将 Key 放入 .env 文件或通过 --dart-define 传入
  await Supabase.initialize(
    url: 'https://avsyxlgfqnrknvvbjxul.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2c3l4bGdmcW5ya252dmJqeHVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzNTk2MjcsImV4cCI6MjA4MDkzNTYyN30.M7FfDZzjYvCt0hSz0W508oSGmzw7tcZ9E5vGyQlnCKY',
  );

  // 4. 本地通知初始化
  if (!kIsWeb) {
    try {
      await NotificationService().init();
    } catch (e) {
      flutter.debugPrint('Notification init failed: $e');
    }
  }

  flutter.runApp(const SmartFoodApp());
}

class SmartFoodApp extends flutter.StatelessWidget {
  const SmartFoodApp({super.key});

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.MaterialApp(
      title: 'Smart Food Home',
      debugShowCheckedModeBanner: false,
      
      // 🟢 5. 统一的主题配置
      theme: flutter.ThemeData(
        useMaterial3: true,
        colorSchemeSeed: BshColors.primary,
        scaffoldBackgroundColor: BshColors.surface,
        
        // 字体配置
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: BshColors.text,
          displayColor: BshColors.text,
        ),
        
        // AppBar 默认样式 (白底黑字，无阴影)
        appBarTheme: const flutter.AppBarTheme(
          backgroundColor: BshColors.surface, // 与背景融合
          elevation: 0,
          scrolledUnderElevation: 0, // 滚动时不改变颜色
          centerTitle: false, // 标题靠左更现代 (可选)
          titleTextStyle: flutter.TextStyle(
            color: BshColors.text,
            fontSize: 22,
            fontWeight: flutter.FontWeight.w800, // 加粗标题
            letterSpacing: -0.5,
          ),
          iconTheme: flutter.IconThemeData(color: BshColors.text),
        ),

        // 按钮默认样式 (圆角)
        filledButtonTheme: flutter.FilledButtonThemeData(
          style: flutter.FilledButton.styleFrom(
            shape: flutter.RoundedRectangleBorder(
              borderRadius: flutter.BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      
      home: const AuthRoot(),
    );
  }
}