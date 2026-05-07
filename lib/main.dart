// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';

import 'repositories/inventory_repository.dart';
import 'screens/add_food_page.dart';
import 'screens/auth_root.dart';
import 'screens/guest_shopping_list_page.dart';
import 'services/notification_service.dart';
import 'utils/app_frame_profiler.dart';
import 'utils/locale_controller.dart';
import 'utils/supabase_config.dart';
import 'utils/theme_controller.dart';


// NOTE: legacy comment cleaned.
class BshColors {
  static const primary = Color(0xFF004A77);
  static const secondary = Color(0xFF50738A);
  static const surface = Color(0xFFF8F9FA);
  static const error = Color(0xFFBA1A1A);
  static const text = Color(0xFF191C1E);
}

const double kDefaultRadius = 16.0;
const double kMenuRadius = 24.0;
const double kMenuElevation = 12.0;

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppFrameProfiler.maybeInstall();

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
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
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
  final localeController = LocaleController();
  await themeController.load();
  await localeController.load();

  if (!kIsWeb) {
    try {
      await NotificationService().syncSchedulesFromPreferences(
        activeItems: inventoryRepo.getActiveItems(),
      );
    } catch (e) {
      debugPrint('Notification schedule sync failed: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: inventoryRepo),
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider.value(value: localeController),
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
    if (settings.name?.startsWith('/guest-list') == true) {
      final token = GuestShoppingListPage.resolveToken(settings);
      if (token == null || token.isEmpty) return null;
      return MaterialPageRoute(
        builder: (_) => GuestShoppingListPage(shareToken: token),
      );
    }
    if (settings.name?.startsWith('/share/') == true) {
      final token = GuestShoppingListPage.resolveToken(settings);
      if (token == null || token.isEmpty) return null;
      return MaterialPageRoute(
        builder: (_) => GuestShoppingListPage(
          shareToken: token,
          lookupById: true,
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeController, LocaleController>(
      builder: (context, themeController, localeController, _) {
        final lightBase = ThemeData.light();
        final darkBase = ThemeData.dark();
        final lightTextTheme = GoogleFonts.dmSansTextTheme(lightBase.textTheme);
        final darkTextTheme = GoogleFonts.dmSansTextTheme(darkBase.textTheme);
        const pageTransitions = PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          },
        );

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
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kDefaultRadius), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kDefaultRadius), borderSide: const BorderSide(color: BshColors.primary, width: 2)),
          ),
          chipTheme: lightBase.chipTheme.copyWith(
            shape: const StadiumBorder(),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            backgroundColor: Colors.white,
            selectedColor: BshColors.primary,
            labelStyle: TextStyle(color: BshColors.text.withValues(alpha: 0.75), fontWeight: FontWeight.w600),
            secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          sliderTheme: lightBase.sliderTheme.copyWith(
            trackHeight: 5,
            activeTrackColor: BshColors.primary.withValues(alpha: 0.9),
            inactiveTrackColor: BshColors.primary.withValues(alpha: 0.18),
            thumbColor: BshColors.primary,
            overlayColor: BshColors.primary.withValues(alpha: 0.14),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return Colors.white;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return BshColors.primary.withValues(alpha: 0.85);
              return Colors.grey.withValues(alpha: 0.35);
            }),
            overlayColor: WidgetStateProperty.all(BshColors.primary.withValues(alpha: 0.12)),
            splashRadius: 18,
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: kMenuElevation,
            shadowColor: Colors.black.withValues(alpha: 0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kMenuRadius),
            ),
            menuPadding: const EdgeInsets.symmetric(vertical: 6),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            menuStyle: MenuStyle(
              elevation: const WidgetStatePropertyAll(kMenuElevation),
              shadowColor: WidgetStatePropertyAll(
                Colors.black.withValues(alpha: 0.16),
              ),
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
              surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kMenuRadius),
                ),
              ),
            ),
          ),
          pageTransitionsTheme: pageTransitions,
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
          chipTheme: darkBase.chipTheme.copyWith(
            shape: const StadiumBorder(),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            backgroundColor: const Color(0xFF1D2432),
            selectedColor: BshColors.secondary,
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w600),
            secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          sliderTheme: darkBase.sliderTheme.copyWith(
            trackHeight: 5,
            activeTrackColor: BshColors.secondary.withValues(alpha: 0.95),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
            thumbColor: Colors.white,
            overlayColor: BshColors.secondary.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return Colors.white.withValues(alpha: 0.9);
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return BshColors.secondary.withValues(alpha: 0.88);
              return Colors.white.withValues(alpha: 0.22);
            }),
            overlayColor: WidgetStateProperty.all(BshColors.secondary.withValues(alpha: 0.2)),
            splashRadius: 18,
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: const Color(0xFF1A1E25),
            surfaceTintColor: Colors.transparent,
            elevation: kMenuElevation,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kMenuRadius),
            ),
            menuPadding: const EdgeInsets.symmetric(vertical: 6),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            menuStyle: MenuStyle(
              elevation: const WidgetStatePropertyAll(kMenuElevation),
              shadowColor: WidgetStatePropertyAll(
                Colors.black.withValues(alpha: 0.35),
              ),
              backgroundColor: const WidgetStatePropertyAll(Color(0xFF1A1E25)),
              surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kMenuRadius),
                ),
              ),
            ),
          ),
          pageTransitionsTheme: pageTransitions,
        );

        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)?.appTitle ?? 'BSH Smart',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          onGenerateRoute: _onGenerateRoute,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeController.themeMode,
          locale: localeController.locale,
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (localeController.locale != null) {
              return localeController.locale;
            }
            final deviceCode = deviceLocale?.languageCode.toLowerCase();
            for (final locale in supportedLocales) {
              if (locale.languageCode == deviceCode) {
                return locale;
              }
            }
            return const Locale('en');
          },
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          // NOTE: legacy comment cleaned.
          home: const AuthRoot(),
        );
      },
    );
  }
}



