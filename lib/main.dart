// lib/main.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/inventory_repository.dart';
import 'screens/add_food_page.dart';
import 'screens/auth_root.dart';
import 'screens/archive_recipe_detail_page.dart';
import 'services/archive_service.dart';
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

const MethodChannel _widgetChannel = MethodChannel('widget_channel');
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> _pushInventorySnapshot(InventoryRepository repo) async {
  final prefs = await SharedPreferences.getInstance();
  final studentMode = prefs.getBool('student_mode') ?? false;
  final items = repo.getActiveItems();
  final payload = {
    'studentMode': studentMode,
    'items': items
        .map((e) => {
              'name': e.name,
              'category': e.category,
              'daysToExpiry': e.daysToExpiry,
            })
        .toList(),
  };
  await _widgetChannel.invokeMethod('updateInventorySnapshot', jsonEncode(payload));
  await _widgetChannel.invokeMethod('refreshRecipeWidget');
}

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

  _widgetChannel.setMethodCallHandler((call) async {
    if (call.method != 'openRoute') return;
    final route = call.arguments as String?;
    if (route == null || route.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.pushNamed(route);
    });
  });

  inventoryRepo.addListener(() {
    _pushInventorySnapshot(inventoryRepo);
  });
  _pushInventorySnapshot(inventoryRepo);

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

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    if (settings.name == '/add-food-scan') {
      return MaterialPageRoute(
        builder: (context) {
          final repo = Provider.of<InventoryRepository>(context, listen: false);
          return AddFoodPage(repo: repo, initialTab: 1);
        },
      );
    }
    if (settings.name == '/widget-recipe') {
      return MaterialPageRoute(builder: (_) => const _WidgetRecipeRoute());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, _) {
        final lightBase = ThemeData.light();
        final darkBase = ThemeData.dark();
        final lightTextTheme = GoogleFonts.dmSansTextTheme(lightBase.textTheme);
        final darkTextTheme = GoogleFonts.dmSansTextTheme(darkBase.textTheme);

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
          navigatorKey: _navigatorKey,
          onGenerateRoute: _onGenerateRoute,
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

class _WidgetRecipeRoute extends StatefulWidget {
  const _WidgetRecipeRoute();

  @override
  State<_WidgetRecipeRoute> createState() => _WidgetRecipeRouteState();
}

class _WidgetRecipeRouteState extends State<_WidgetRecipeRoute> {
  ArchivedRecipe? _recipe;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    final pendingJson = await _widgetChannel.invokeMethod<String>('getPendingRecipe');
    final pendingOpenId = await _widgetChannel.invokeMethod<String>('getPendingOpenRecipeId');

    ArchivedRecipe? pendingRecipe;
    if (pendingJson != null && pendingJson.trim().isNotEmpty) {
      try {
        pendingRecipe = ArchivedRecipe.fromJson(jsonDecode(pendingJson));
        final exists = await ArchiveService.instance.containsRecipeId(pendingRecipe.recipeId);
        if (!exists) {
          await ArchiveService.instance.add(pendingRecipe);
        }
        await _widgetChannel.invokeMethod('clearPendingRecipe');
      } catch (_) {}
    }

    if (pendingOpenId != null) {
      await _widgetChannel.invokeMethod('clearPendingOpenRecipeId');
    }

    ArchivedRecipe? resolved;
    if (pendingOpenId != null && pendingOpenId.isNotEmpty) {
      final list = await ArchiveService.instance.getAll();
      for (final r in list) {
        if (r.recipeId == pendingOpenId) {
          resolved = r;
          break;
        }
      }
    }
    resolved ??= pendingRecipe;

    if (mounted) {
      setState(() {
        _recipe = resolved;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Recipe', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700)),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: colors.onSurface),
        ),
        body: Center(
          child: Text(
            'Chef is thinking...',
            style: TextStyle(color: colors.onSurface.withOpacity(0.6)),
          ),
        ),
      );
    }

    final recipe = _recipe;
    if (recipe == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Recipe', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700)),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: colors.onSurface),
        ),
        body: Center(
          child: Text(
            'Add items to get recipes',
            style: TextStyle(color: colors.onSurface.withOpacity(0.6)),
          ),
        ),
      );
    }

    return ArchiveRecipeDetailPage(recipe: recipe);
  }
}
