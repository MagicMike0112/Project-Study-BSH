// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/inventory_repository.dart';
import 'screens/auth_root.dart';
import 'services/notification_service.dart';
// 🟢 1. 引入长辈模式主页
import 'screens/senior_home.dart';

// 🎨 标准配色 (BSH Blue)
class BshColors {
  static const primary = Color(0xFF004A77);
  static const secondary = Color(0xFF50738A);
  static const surface = Color(0xFFF8F9FA);
  static const error = Color(0xFFBA1A1A);
  static const text = Color(0xFF191C1E);
}

// 👵 长辈模式配色
class SeniorColors {
  static const primary = Color(0xFF004A77);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF000000);
}

const double kDefaultRadius = 16.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Supabase.initialize(
    url: 'https://avsyxlgfqnrknvvbjxul.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2c3l4bGdmcW5ya252dmJqeHVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzNTk2MjcsImV4cCI6MjA4MDkzNTYyN30.M7FfDZzjYvCt0hSz0W508oSGmzw7tcZ9E5vGyQlnCKY',
  );

  if (!kIsWeb) {
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  final inventoryRepo = await InventoryRepository.create();

  runApp(
    ChangeNotifierProvider.value(
      value: inventoryRepo,
      child: const SmartFoodApp(),
    ),
  );
}

class SmartFoodApp extends StatelessWidget {
  const SmartFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<InventoryRepository>(context);
    final isSenior = repo.isSeniorMode;
    
    final baseTextTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    // === 标准主题 ===
    final standardTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: BshColors.primary,
      scaffoldBackgroundColor: BshColors.surface,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.blue,
        accentColor: BshColors.secondary,
        backgroundColor: BshColors.surface,
        errorColor: BshColors.error,
      ).copyWith(
        secondary: BshColors.secondary,
      ),

      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800, color: BshColors.text),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: BshColors.text),
        titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: BshColors.text),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: BshColors.text),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: BshColors.surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: BshColors.text),
        titleTextStyle: TextStyle(color: BshColors.text, fontSize: 22, fontWeight: FontWeight.w700),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kDefaultRadius)),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kDefaultRadius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kDefaultRadius), borderSide: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kDefaultRadius), borderSide: const BorderSide(color: BshColors.primary, width: 2)),
      ),
    );

    // === 长辈主题 ===
    final seniorTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: SeniorColors.primary,
      scaffoldBackgroundColor: SeniorColors.surface,
      
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.blue,
        backgroundColor: SeniorColors.surface,
      ).copyWith(
        secondary: SeniorColors.primary,
        onSurface: SeniorColors.text,
      ),

      textTheme: baseTextTheme.copyWith(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: SeniorColors.text),
        headlineMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: SeniorColors.text),
        titleLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SeniorColors.text),
        bodyLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: SeniorColors.text),
        bodyMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
        labelLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.black, size: 32),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          backgroundColor: SeniorColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(24),
        labelStyle: const TextStyle(fontSize: 22, color: Colors.black),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SeniorColors.primary, width: 3)),
      ),
    );

    return MaterialApp(
      title: 'Smart Food Home',
      debugShowCheckedModeBanner: false,
      theme: isSenior ? seniorTheme : standardTheme,
      // 🟢 2. 路由分叉：长辈模式进入专用主页，否则进入普通主页
      home: isSenior ? const SeniorHome() : const AuthRoot(),
    );
  }
}