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
import 'utils/theme_controller.dart';


// 🎨 标准配色
class BshColors {
  static const primary = Color(0xFF004A77);
  static const secondary = Color(0xFF50738A);
  static const surface = Color(0xFFF8F9FA);
  static const error = Color(0xFFBA1A1A);
  static const text = Color(0xFF191C1E);
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
  final themeController = ThemeController();
  await themeController.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: inventoryRepo),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: const SmartFoodApp(),
    ),
  );
}

class SmartFoodApp extends StatelessWidget {
  const SmartFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, _) {
        final lightBase = ThemeData.light();
        final darkBase = ThemeData.dark();
        final lightTextTheme = GoogleFonts.interTextTheme(lightBase.textTheme);
        final darkTextTheme = GoogleFonts.interTextTheme(darkBase.textTheme);

        final lightTheme = ThemeData(
          brightness: Brightness.light,
          primaryColor: BshColors.primary,
          scaffoldBackgroundColor: BshColors.surface,
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue,
            accentColor: BshColors.secondary,
            backgroundColor: BshColors.surface,
            errorColor: BshColors.error,
          ).copyWith(secondary: BshColors.secondary),
          textTheme: lightTextTheme.copyWith(
            displayLarge: lightTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800, color: BshColors.text),
            headlineMedium: lightTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: BshColors.text),
            titleLarge: lightTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: BshColors.text),
            bodyLarge: lightTextTheme.bodyLarge?.copyWith(color: BshColors.text),
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

        final darkTheme = ThemeData(
          brightness: Brightness.dark,
          colorScheme: darkBase.colorScheme.copyWith(secondary: BshColors.secondary),
          textTheme: darkTextTheme,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF111418),
            elevation: 0,
            centerTitle: false,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
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
            fillColor: const Color(0xFF1C1F24),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(kDefaultRadius), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kDefaultRadius), borderSide: BorderSide(color: Colors.white12, width: 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kDefaultRadius), borderSide: const BorderSide(color: BshColors.secondary, width: 2)),
          ),
        );

        return MaterialApp(
          title: 'Smart Food Home',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeController.themeMode,

          // 🟢 回归单一入口
          home: const AuthRoot(),
        );
      },
    );
  }
}
