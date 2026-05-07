// ignore_for_file: unused_field, unused_element, unused_element_parameter
// lib/screens/impact_page.dart
import 'dart:ui';

import '../utils/app_haptics.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

// NOTE: legacy comment cleaned.

import '../repositories/inventory_repository.dart';
import '../utils/app_typography.dart';
import '../utils/impact_helpers.dart';
import '../utils/showcase_utils.dart';
import '../l10n/app_localizations.dart';
import '../widgets/profile_avatar_button.dart';
import 'leaderboard_page.dart';
import 'weekly_report_page.dart';

enum ImpactRange { week, month, year }
enum ImpactMascot { cat, dog, hamster, guineaPig }

class _MascotSelection {
  final ImpactMascot mascot;

  const _MascotSelection({required this.mascot});
}

class _ImpactStyle {
  static const Color primary = Color(0xFF58CC02); // vibrant green
  static const Color secondary = Color(0xFF2B70C9); // vibrant blue
  static const Color accent = Color(0xFFFF9600); // orange
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF202F36);
  static const Color bgLight = Color(0xFFF0F4F8);
  static const Color bgDark = Color(0xFF131F24);

  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? surfaceDark : surfaceLight;
  }

  static List<BoxShadow> softShadow(bool isDark) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

class ImpactPageWrapper extends StatefulWidget {
  final InventoryRepository repo;
  final bool isActive;

  const ImpactPageWrapper({
    super.key,
    required this.repo,
    required this.isActive,
  });

  @override
  State<ImpactPageWrapper> createState() => _ImpactPageWrapperState();
}

class _ImpactPageWrapperState extends State<ImpactPageWrapper> {
  final GlobalKey _weeklyKey = GlobalKey();
  final GlobalKey _rangeKey = GlobalKey();
  final GlobalKey _heroKey = GlobalKey();
  bool _didShow = false;

  Future<void> _maybeShowTutorial(BuildContext context) async {
    await ShowcaseCoordinator.startPageShowcase(
      context: context,
      hasAttempted: _didShow,
      markAttempted: () => _didShow = true,
      isPageVisibleNow: () => mounted && widget.isActive,
      isDataReadyNow: () => !widget.repo.isLoading,
      seenPrefKey: 'hasShownIntro_impact_v1',
      keys: [_weeklyKey, _rangeKey, _heroKey],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) {
        if (widget.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial(context));
        }
        return ImpactPage(
          repo: widget.repo,
          weeklyKey: _weeklyKey,
          rangeKey: _rangeKey,
          heroKey: _heroKey,
        );
      },
    );
  }
}

class ImpactPage extends StatefulWidget {
  final InventoryRepository repo;
  final GlobalKey? weeklyKey;
  final GlobalKey? rangeKey;
  final GlobalKey? heroKey;
  const ImpactPage({
    super.key,
    required this.repo,
    this.weeklyKey,
    this.rangeKey,
    this.heroKey,
  });

  @override
  State<ImpactPage> createState() => _ImpactPageState();
}

class _ImpactPageState extends State<ImpactPage> {
  ImpactRange _range = ImpactRange.week;
  ImpactMascot _mascot = ImpactMascot.hamster;
  String _mascotName = 'Buddy';
  static const String _defaultMascotName = 'Buddy';
  static const String _mascotPrefKey = 'impact_mascot';
  static const String _mascotNamePrefKey = 'impact_mascot_name';

  // NOTE: legacy comment cleaned.
  int _streak = 0;
  double _moneyTotal = 0.0;
  double _co2Total = 0.0;
  int _savedCount = 0;
  List<ImpactEvent> _recentEvents = [];
  List<ImpactEvent> _petEvents = [];
  List<MapEntry<String, double>> _topCategories = [];
  double _petQty = 0.0;
  double _petShare = 0.0;
  int _petItemCount = 0;
  List<FlSpot> _moneySpots = [];
  Map<int, String> _chartLabels = {};
  bool _hasEnoughData = false;
  bool _isEmpty = true;
  bool _depsReady = false;

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onRepoChanged);
    _loadMascotPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final m in ImpactMascot.values) {
        precacheImage(AssetImage(_mascotAssetPath(m)), context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _depsReady = true;
    _calculateImpactData();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (!_depsReady) return;
    _calculateImpactData();
  }

  void _changeRange(ImpactRange r) {
    if (_range == r) return;
    AppHaptics.selection();
    setState(() {
      _range = r;
    });
    _calculateImpactData();
  }

  String _mascotLabel(BuildContext context, ImpactMascot m) {
    final l10n = AppLocalizations.of(context);
    switch (m) {
      case ImpactMascot.cat:
        return l10n?.impactMascotCat ?? 'Cat';
      case ImpactMascot.dog:
        return l10n?.impactMascotDog ?? 'Dog';
      case ImpactMascot.hamster:
        return l10n?.impactMascotHamster ?? 'Hamster';
      case ImpactMascot.guineaPig:
        return l10n?.impactMascotGuineaPig ?? 'Guinea Pig';
    }
  }

  String _mascotAssetPath(ImpactMascot m) {
    switch (m) {
      case ImpactMascot.cat:
        return 'assets/pets/cat.png';
      case ImpactMascot.dog:
        return 'assets/pets/dog.png';
      case ImpactMascot.hamster:
        return 'assets/pets/hamster.png';
      case ImpactMascot.guineaPig:
        return 'assets/pets/guinea pig.png';
    }
  }

  Future<void> _loadMascotPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final mascotIndex = prefs.getInt(_mascotPrefKey);
    final name = prefs.getString(_mascotNamePrefKey);
    if (!mounted) return;
    setState(() {
      if (mascotIndex != null && mascotIndex >= 0 && mascotIndex < ImpactMascot.values.length) {
        _mascot = ImpactMascot.values[mascotIndex];
      }
      if (name != null && name.trim().isNotEmpty) {
        _mascotName = name.trim();
      }
    });
  }

  Future<void> _saveMascotPrefs({ImpactMascot? mascot, String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    if (mascot != null) {
      await prefs.setInt(_mascotPrefKey, mascot.index);
    }
    if (name != null) {
      await prefs.setString(_mascotNamePrefKey, name);
    }
  }

  Future<void> _openMascotPicker() async {
    ImpactMascot selected = _mascot;
    bool isSaving = false;

    final result = await showModalBottomSheet<_MascotSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // NOTE: legacy comment cleaned.
      clipBehavior: Clip.hardEdge,
      // NOTE: legacy comment cleaned.
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
        final isDark = theme.brightness == Brightness.dark;
        final glassColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.78);

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              // NOTE: legacy comment cleaned.
              child: StatefulBuilder(
                builder: (ctx, setSheetState) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 16),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                        l10n?.impactChooseMascot ?? 'Choose your mascot',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: colors.onSurface),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: ImpactMascot.values.map((m) {
                          final isSelected = selected == m;
                          return InkWell(
                            // NOTE: legacy comment cleaned.
                            onTap: () => setSheetState(() => selected = m),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _ImpactStyle.primary.withValues(alpha: 0.18)
                                    : theme.cardColor.withValues(alpha: isDark ? 0.6 : 1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? _ImpactStyle.primary.withValues(alpha: 0.6)
                                      : theme.dividerColor.withValues(alpha: 0.8),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: _ImpactStyle.primary.withValues(alpha: 0.25),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? 1.05 : 1,
                                    duration: const Duration(milliseconds: 180),
                                    child: Icon(
                                      Icons.pets,
                                      size: 16,
                                      color: isSelected
                                          ? _ImpactStyle.primary
                                          : colors.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _mascotLabel(ctx, m),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: isSelected
                                          ? _ImpactStyle.primary
                                          : colors.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          // NOTE: legacy comment cleaned.
                          // NOTE: legacy comment cleaned.
                          onPressed: isSaving 
                              ? null 
                              : () async {
                                  // NOTE: legacy comment cleaned.
                                  setSheetState(() => isSaving = true);

                                  try {
                                    // NOTE: legacy comment cleaned.
                                    FocusManager.instance.primaryFocus?.unfocus();

                                    // NOTE: legacy comment cleaned.
                                    await Future.delayed(const Duration(milliseconds: 300));

                                    // NOTE: legacy comment cleaned.
                                    if (!ctx.mounted) return;

                                    
                                    // NOTE: legacy comment cleaned.
                                    if (Navigator.of(ctx).canPop()) {
                                      Navigator.of(ctx).pop(
                                        _MascotSelection(
                                          mascot: selected,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint("Error closing sheet: $e");
                                    // NOTE: legacy comment cleaned.
                                    if (ctx.mounted) {
                                       setSheetState(() => isSaving = false);
                                    }
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: _ImpactStyle.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSaving 
                              // NOTE: legacy comment cleaned.
                              ? const SizedBox(
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                )
                              : Text(l10n?.commonSave ?? 'Save', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
      },
    );

    // NOTE: legacy comment cleaned.

    // NOTE: legacy comment cleaned.
    if (!mounted || result == null) return;

    // NOTE: legacy comment cleaned.
    setState(() {
      _mascot = result.mascot;
    });
    _saveMascotPrefs(mascot: result.mascot);
  }

  Future<void> _editMascotName() async {
    if (_mascotName != _defaultMascotName) return;
    if (!mounted) return;
    final controller = TextEditingController(text: _mascotName);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(l10n?.impactMascotNameTitle ?? 'Mascot name', style: const TextStyle(fontWeight: FontWeight.w800)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: l10n?.impactMascotNameHint ?? 'Give it a name',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (Navigator.of(ctx).canPop()) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
              style: TextButton.styleFrom(foregroundColor: colors.primary),
              child: Text(l10n?.commonSave ?? 'Save', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted) return;
    final name = (result ?? '').trim();
    if (name.isEmpty || name == _mascotName) return;
    setState(() => _mascotName = name);
    Future(() => _saveMascotPrefs(name: name));
  }

  Future<void> _showPetItemsSheet() async {
    if (_petEvents.isEmpty || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            itemCount: _petEvents.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  (l10n?.impactFedToMascot(_mascotName)) ?? 'Fed to $_mascotName',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: colors.onSurface),
                );
              }
              final event = _petEvents[index - 1];
              final title = event.itemName?.trim().isNotEmpty == true ? event.itemName! : (l10n?.impactItemFallback ?? 'Item');
              final dateLabel = '${event.date.month}/${event.date.day}';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.pets, size: 18, color: Colors.orange.shade400),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                            '$dateLabel - ${event.quantity.toStringAsFixed(1)} ${event.unit}',
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  DateTime _rangeStart() {
    final now = DateTime.now();
    switch (_range) {
      case ImpactRange.week:
        return now.subtract(const Duration(days: 7));
      case ImpactRange.month:
        return DateTime(now.year, now.month - 1, now.day);
      case ImpactRange.year:
        return DateTime(now.year - 1, now.month, now.day);
    }
  }

  String _shortDate(BuildContext context, DateTime d) =>
      MaterialLocalizations.of(context).formatShortDate(d);

  // NOTE: legacy comment cleaned.
  String _inferCategory(String? cat, String? name) {
    final c = (cat ?? '').toLowerCase();
    final n = (name ?? '').toLowerCase();

    // NOTE: legacy comment cleaned.
    if (c.contains('veg') || c.contains('salad')) return 'Veggies';
    if (c.contains('fruit') || c.contains('berry')) return 'Fruits';
    if (c.contains('meat') || c.contains('beef') || c.contains('pork') || c.contains('chicken') || c.contains('fish')) return 'Protein';
    if (c.contains('dairy') || c.contains('cheese') || c.contains('milk') || c.contains('yogurt')) return 'Dairy';
    if (c.contains('bread') || c.contains('rice') || c.contains('pasta') || c.contains('noodle') || c.contains('cereal')) return 'Carbs';
    if (c.contains('snack') || c.contains('chip') || c.contains('chocolate')) return 'Snacks';
    if (c.contains('drink') || c.contains('beverage') || c.contains('juice') || c.contains('coffee') || c.contains('tea')) return 'Drinks';

    // NOTE: legacy comment cleaned.
    if (n.contains('onion') || n.contains('carrot') || n.contains('potato') || n.contains('tomato') || n.contains('spinach') || n.contains('lettuce') || n.contains('cucumber') || n.contains('pepper') || n.contains('broccoli')) return 'Veggies';
    if (n.contains('banana') || n.contains('apple') || n.contains('orange') || n.contains('grape') || n.contains('berry') || n.contains('lemon')) return 'Fruits';
    if (n.contains('egg') || n.contains('tofu') || n.contains('bean') || n.contains('sausage') || n.contains('ham')) return 'Protein';
    if (n.contains('rice') || n.contains('bread') || n.contains('toast') || n.contains('bagel') || n.contains('pizza')) return 'Carbs';
    if (n.contains('milk') || n.contains('butter') || n.contains('cream')) return 'Dairy';
    if (n.contains('water') || n.contains('coke') || n.contains('soda') || n.contains('beer') || n.contains('wine')) return 'Drinks';

    // NOTE: legacy comment cleaned.
    if (c == 'manual' || c.isEmpty) return 'General';
    return c;
  }

  // NOTE: legacy comment cleaned.
  void _calculateImpactData() {
    final start = _rangeStart();
    final allEvents = widget.repo.impactEvents;

    // NOTE: legacy comment cleaned.
    final relevantEvents = <ImpactEvent>[];
    final petEvents = <ImpactEvent>[];
    final categoryMap = <String, double>{};
    final dailyMoney = <DateTime, double>{};
    
    double moneySum = 0;
    double co2Sum = 0;
    double petQtySum = 0;
    double totalQtySum = 0;
    int petItemCount = 0;

    // NOTE: legacy comment cleaned.
    for (final e in allEvents) {
      if (!e.date.isBefore(start)) {
        relevantEvents.add(e);

        moneySum += e.moneySaved;
        co2Sum += e.co2Saved;
        totalQtySum += e.quantity;

        // NOTE: legacy comment cleaned.
        if (e.type == ImpactType.eaten) {
          final cat = _inferCategory(e.itemCategory, e.itemName);
          categoryMap[cat] = (categoryMap[cat] ?? 0) + e.moneySaved;
        }

        // NOTE: legacy comment cleaned.
        if (e.type == ImpactType.fedToPet) {
          petQtySum += e.quantity;
          petItemCount += 1;
          petEvents.add(e);
        }

        // NOTE: legacy comment cleaned.
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        dailyMoney[d] = (dailyMoney[d] ?? 0) + e.moneySaved;
      }
    }

    // NOTE: legacy comment cleaned.
    relevantEvents.sort((a, b) => b.date.compareTo(a.date));
    final recent = relevantEvents.take(5).toList();
    petEvents.sort((a, b) => b.date.compareTo(a.date));

    // NOTE: legacy comment cleaned.
    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCats = sortedCategories.take(3).toList();

    // NOTE: legacy comment cleaned.
    final share = totalQtySum == 0 ? 0.0 : (petQtySum / totalQtySum).clamp(0.0, 1.0);

    // NOTE: legacy comment cleaned.
    final allDates = dailyMoney.keys.toList()..sort();
    final spots = <FlSpot>[];
    final labels = <int, String>{};

    for (var i = 0; i < allDates.length; i++) {
      final d = allDates[i];
      final x = i.toDouble();
      spots.add(FlSpot(x, dailyMoney[d] ?? 0));
      labels[i] = _shortDate(context, d);
    }

    if (mounted) {
      setState(() {
        _streak = widget.repo.getCurrentStreakDays();
        _moneyTotal = moneySum;
        _co2Total = co2Sum;
        _savedCount = relevantEvents.length;
        _recentEvents = recent;
        _petEvents = petEvents;
        _topCategories = topCats;
        _petQty = petQtySum;
        _petShare = share;
        _petItemCount = petItemCount;
        _moneySpots = spots;
        _chartLabels = labels;
        _hasEnoughData = spots.isNotEmpty;
        _isEmpty = relevantEvents.isEmpty;
      });
    }
  }

  Widget _wrapShowcase({
    required GlobalKey? key,
    required String title,
    required String description,
    required Widget child,
  }) {
    return wrapWithShowcase(
      context: context,
      key: key,
      title: title,
      description: description,
      child: child,
    );
  }

  static const Color _accentColor = _ImpactStyle.primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? _ImpactStyle.bgDark : _ImpactStyle.bgLight,
      // NOTE: legacy comment cleaned.
      resizeToAvoidBottomInset: false, 
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            toolbarHeight: 72,
            floating: false,
            pinned: true,
            backgroundColor: _ImpactStyle.surface(context),
            elevation: 0,
            systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            titleSpacing: 20,
            title: Text(
              l10n?.impactTitle ?? 'Your Impact',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: kMainPageTitleFontSize,
              ),
            ),
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _ImpactStyle.accent.withValues(alpha: isDark ? 0.2 : 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department, color: _ImpactStyle.accent, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '$_streak',
                      style: TextStyle(color: _ImpactStyle.accent, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Center(child: ProfileAvatarButton(repo: widget.repo)),
              const SizedBox(width: 16),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInSlide(
                    index: 0,
                    child: _wrapShowcase(
                      key: widget.rangeKey,
                      title: l10n?.impactTimeRangeTitle ?? 'Time Range',
                      description: l10n?.impactTimeRangeDescription ??
                          'Switch between week, month, and year views.',
                      child: _SlidingRangeSelector(
                        currentRange: _range,
                        onChanged: _changeRange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    index: 1,
                    child: _wrapShowcase(
                      key: widget.heroKey,
                      title: l10n?.impactSummaryTitle ?? 'Impact Summary',
                      description: l10n?.impactSummaryDescription ??
                          'See money saved and items rescued here.',
                      child: _TotalSavingsCard(
                        moneySaved: _moneyTotal,
                        savedCount: _savedCount,
                        showProjection: _range == ImpactRange.week,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    index: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: _GamifiedStatCard(
                            title: l10n?.impactLevelTitle ?? 'Level',
                            value: '${math.max(1, (_co2Total / 3).round())}',
                            subtitle: l10n?.impactKgAvoided(_co2Total.toStringAsFixed(1)) ??
                                '${_co2Total.toStringAsFixed(1)}kg avoided',
                            icon: Icons.public,
                            color: _ImpactStyle.primary,
                            tone: const Color(0xFFE6F7D7),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _GamifiedStatCard(
                            title: l10n?.impactStreakTitle ?? 'Streak',
                            value: '$_streak',
                            subtitle: l10n?.impactDaysActive ?? 'Days active',
                            icon: Icons.local_fire_department,
                            color: _ImpactStyle.accent,
                            tone: const Color(0xFFFFE9CF),
                            badge: l10n?.impactActiveBadge ?? 'Active',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    index: 3,
                    child: _wrapShowcase(
                      key: widget.weeklyKey,
                      title: l10n?.impactWeeklyReportTitle ?? 'Weekly Report',
                      description: l10n?.impactWeeklyReportDescription ??
                          'Open your AI weekly summary and insights.',
                      child: _WeeklyReportCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WeeklyReportPage(repo: widget.repo),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_petItemCount > 0)
                    FadeInSlide(
                      index: 4,
                      child: _PetImpactCard(
                        mascotAsset: _mascotAssetPath(_mascot),
                        fedItemCount: _petItemCount,
                        petQty: _petQty,
                        petShare: _petShare,
                        onTap: _showPetItemsSheet,
                        onLongPress: _openMascotPicker,
                      ),
                    ),
                  if (_petItemCount > 0) const SizedBox(height: 16),
                  FadeInSlide(
                    index: 5,
                    child: _CommunityQuestCard(
                      co2Saved: _co2Total,
                      savedCount: _savedCount,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeaderboardPage()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_recentEvents.isNotEmpty)
                    FadeInSlide(
                      index: 6,
                      child: _RecentActionsList(
                        events: _recentEvents,
                        resolveName: widget.repo.resolveUserNameById,
                      ),
                    )
                  else if (_isEmpty)
                    FadeInSlide(index: 6, child: _EmptyStateCard()),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 80 + MediaQuery.of(context).padding.bottom),
          ),
        ],
      ),
    );
  }
}

// ===================== UI Components =====================

class _ImpactBadgeHero extends StatelessWidget {
  final int savedCount;
  final int streak;
  final String mascotLabel;
  final String mascotAsset;
  final String mascotName;
  final VoidCallback onLongPress;
  final VoidCallback? onNameTap;
  final bool canEditName;

  const _ImpactBadgeHero({
    required this.savedCount,
    required this.streak,
    required this.mascotLabel,
    required this.mascotAsset,
    required this.mascotName,
    required this.onLongPress,
    this.onNameTap,
    this.canEditName = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: GestureDetector(
            onLongPress: onLongPress,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 18)],
                  ),
                ),
                _FloatingMascotImage(assetPath: mascotAsset, fallbackLabel: mascotLabel),
                Positioned(
                  bottom: 2,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _ImpactStyle.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.thumb_up, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            l10n?.impactFridgeMasterTitle ?? 'Fridge Master!',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colors.onSurface),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            l10n?.impactSavedItemsStreak(savedCount, streak) ??
                'Saved $savedCount items - $streak day streak',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: GestureDetector(
            onTap: canEditName ? onNameTap : null,
            child: Text(
              mascotName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: _ImpactStyle.secondary,
                decoration: canEditName ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalSavingsCard extends StatelessWidget {
  final double moneySaved;
  final int savedCount;
  final bool showProjection;

  const _TotalSavingsCard({
    required this.moneySaved,
    required this.savedCount,
    required this.showProjection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = moneySaved <= 0 ? 0.0 : (moneySaved / 18.0).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ImpactStyle.secondary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _ImpactStyle.softShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n?.impactTotalSavingsLabel ?? 'TOTAL SAVINGS',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
              const Spacer(),
              const Icon(Icons.stars, color: Colors.yellowAccent),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: moneySaved),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              final whole = value.floorToDouble();
              final cents = ((value - whole) * 100).round().clamp(0, 99);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('\$', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text(
                    whole.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '.${cents.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n?.impactNextRankLabel ?? 'Next Rank: Zero Waste Hero',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('${(pct * 100).round()}%', style: const TextStyle(color: Colors.yellowAccent, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 10,
                        backgroundColor: Colors.black.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD24A)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  l10n?.impactBasedOnSavedItems(savedCount) ?? 'Based on $savedCount items saved',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (showProjection) ...[
            const SizedBox(height: 8),
            Text(
              l10n?.impactOnTrackYearly((moneySaved * 12).toStringAsFixed(0)) ??
                  'On track to save \$${(moneySaved * 12).toStringAsFixed(0)} / year',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _GamifiedStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color tone;
  final String? badge;

  const _GamifiedStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tone,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ImpactStyle.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
        boxShadow: _ImpactStyle.softShadow(Theme.of(context).brightness == Brightness.dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge!, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colors.onSurface)),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReportCard extends StatelessWidget {
  final VoidCallback onTap;
  const _WeeklyReportCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _ImpactStyle.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
          boxShadow: _ImpactStyle.softShadow(Theme.of(context).brightness == Brightness.dark),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
              ),
              child: Icon(Icons.bar_chart_rounded, color: _ImpactStyle.secondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.impactWeeklyReportTitle ?? 'Weekly Report',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.impactWeeklyReviewSubtitle ?? 'Review your progress from last week',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _ImpactStyle.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward, color: _ImpactStyle.secondary, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityQuestCard extends StatelessWidget {
  final double co2Saved;
  final int savedCount;
  final VoidCallback onTap;

  const _CommunityQuestCard({required this.co2Saved, required this.savedCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF6B4BCB),
        borderRadius: BorderRadius.circular(24),
        boxShadow: _ImpactStyle.softShadow(Theme.of(context).brightness == Brightness.dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n?.impactCommunityQuestTitle ?? 'Community Quest',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n?.impactNewBadge ?? 'New!',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n?.impactYouSavedCo2ThisWeek(co2Saved.toStringAsFixed(1)) ??
                'You saved ${co2Saved.toStringAsFixed(1)}kg CO2 this week!',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6B4BCB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                l10n?.impactViewLeaderboard ?? 'View Leaderboard',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSaversList extends StatelessWidget {
  final List<MapEntry<String, double>> categories;

  const _TopSaversList({required this.categories});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l10n?.impactTopSaversTitle ?? 'Top Savers',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900, color: colors.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n?.impactSeeAll ?? 'See all', style: TextStyle(color: _ImpactStyle.secondary, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _ImpactStyle.surface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: categories.take(3).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    top: idx == 0 ? BorderSide.none : BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _ImpactStyle.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.eco, color: _ImpactStyle.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.key, style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface)),
                          Text(
                            l10n?.impactMostSavedLabel ?? 'Most Saved',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+\$${item.value.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900, color: _ImpactStyle.primary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _RecentActionsList extends StatelessWidget {
  final List<ImpactEvent> events;
  final String? Function(String?) resolveName;

  const _RecentActionsList({
    required this.events,
    required this.resolveName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final items = events.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l10n?.impactRecentActionsTitle ?? 'Recent Actions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900, color: colors.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n?.impactFamilyLabel ?? 'Family', style: TextStyle(color: _ImpactStyle.secondary, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: items
              .map(
                (e) => _RecentActionTile(
                  event: e,
                  actorName: resolveName(e.userId),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _FloatingMascotImage extends StatefulWidget {
  final String assetPath;
  final String fallbackLabel;

  const _FloatingMascotImage({
    required this.assetPath,
    required this.fallbackLabel,
  });

  @override
  State<_FloatingMascotImage> createState() => _FloatingMascotImageState();
}

class _FloatingMascotImageState extends State<_FloatingMascotImage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRouteActive = ModalRoute.of(context)?.isCurrent ?? true;
    return TickerMode(
      enabled: isRouteActive,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final offset = 6 * (0.5 - (0.5 - _controller.value).abs());
            return Transform.translate(
              offset: Offset(0, -offset),
              child: child,
            );
          },
          child: Container(
            width: 84,
            height: 96,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
            ),
            child: Center(
              child: Image.asset(
                widget.assetPath,
                fit: BoxFit.contain,
                width: 72,
                height: 80,
                cacheWidth: 160,
                cacheHeight: 180,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stack) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pets, size: 30, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
                      const SizedBox(height: 6),
                      Text(
                        widget.fallbackLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MascotSelector extends StatelessWidget {
  final ImpactMascot selected;
  final ValueChanged<ImpactMascot> onChanged;

  const _MascotSelector({required this.selected, required this.onChanged});

  String _label(BuildContext context, ImpactMascot m) {
    final l10n = AppLocalizations.of(context);
    switch (m) {
      case ImpactMascot.cat:
        return l10n?.impactMascotCat ?? 'Cat';
      case ImpactMascot.dog:
        return l10n?.impactMascotDog ?? 'Dog';
      case ImpactMascot.hamster:
        return l10n?.impactMascotHamster ?? 'Hamster';
      case ImpactMascot.guineaPig:
        return l10n?.impactMascotGuineaPig ?? 'Guinea Pig';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ImpactMascot.values.map((m) {
        final isSelected = m == selected;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: InkWell(
            onTap: () => onChanged(m),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _ImpactStyle.primary.withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? _ImpactStyle.primary.withValues(alpha: 0.5)
                      : theme.dividerColor.withValues(alpha: 0.6),
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: _ImpactStyle.primary.withValues(alpha: 0.25), blurRadius: 12)]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.pets, size: 16, color: isSelected ? _ImpactStyle.primary : colors.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    _label(context, m),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? _ImpactStyle.primary : colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecentActionTile extends StatelessWidget {
  final ImpactEvent event;
  final String? actorName;
  const _RecentActionTile({required this.event, required this.actorName});

  String _actionLabel(BuildContext context, ImpactType type) {
    final l10n = AppLocalizations.of(context);
    switch (type) {
      case ImpactType.eaten:
        return l10n?.impactActionCooked ?? 'Cooked';
      case ImpactType.fedToPet:
        return l10n?.impactActionFedToPet ?? 'Fed to pet';
      case ImpactType.trash:
        return l10n?.impactActionWasted ?? 'Wasted';
    }
  }

  Color _actionColor(ImpactType type) {
    switch (type) {
      case ImpactType.eaten:
        return const Color(0xFF2E7D32);
      case ImpactType.fedToPet:
        return const Color(0xFF6A1B9A);
      case ImpactType.trash:
        return const Color(0xFFD32F2F);
    }
  }

  IconData _actionIcon(ImpactType type) {
    switch (type) {
      case ImpactType.eaten:
        return Icons.restaurant_rounded;
      case ImpactType.fedToPet:
        return Icons.pets_rounded;
      case ImpactType.trash:
        return Icons.delete_sweep_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final action = _actionLabel(context, event.type);
    final color = _actionColor(event.type);
    final name = actorName ?? (l10n?.impactFamilyLabel ?? 'Family');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _ImpactStyle.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: _ImpactStyle.softShadow(isDark),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_actionIcon(event.type), size: 18, color: color),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: _UserAvatarBadge(name: name, size: 16),
            ),
          ],
        ),
        title: Text(
          event.itemName ?? (l10n?.impactItemFallback ?? 'Item'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        subtitle: Text(
          action,
          style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
        ),
        trailing: Text(
          '${event.quantity.toStringAsFixed(1)} ${event.unit}',
          style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

class _UserAvatarBadge extends StatelessWidget {
  final String name;
  final double size;
  const _UserAvatarBadge({required this.name, this.size = 18});

  Color _getNameColor(String name) {
    if (name.isEmpty) return Colors.grey;
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink];
    return colors[name.hashCode.abs() % colors.length].shade400;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getNameColor(name);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

class _WeeklyReportBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _WeeklyReportBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _ImpactStyle.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
          boxShadow: _ImpactStyle.softShadow(isDark),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _ImpactStyle.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome, color: _ImpactStyle.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.impactWeeklyReportTitle ?? 'Weekly Report',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    l10n?.impactTapForDietInsights ?? 'Tap to view your diet insights',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _ImpactStyle.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactHeroCard extends StatelessWidget {
  final double moneySaved;
  final int savedCount;
  final String rangeMode;

  const _ImpactHeroCard({
    required this.moneySaved,
    required this.savedCount,
    required this.rangeMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final primaryDark = Color.lerp(primary, Colors.black, 0.2) ?? primary;
    final primaryLight = Color.lerp(primary, Colors.white, 0.2) ?? primary;
    final equivalent = ImpactHelpers.getMoneyEquivalent(moneySaved);
    final projection = ImpactHelpers.getProjectedSavings(moneySaved, rangeMode);
    final title = ImpactHelpers.getSavingsTitle(moneySaved);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryDark,
            primary,
            primaryLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.stars_rounded, color: Colors.amber.shade200, size: 26),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('\$', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              Text(
                moneySaved.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -2.0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 36),
                child: Text('.${(moneySaved % 1 * 100).toStringAsFixed(0).padLeft(2, '0')}', style: const TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            projection,
            style: const TextStyle(color: Color(0xFFD6F2F6), fontSize: 13, fontWeight: FontWeight.w500),
          ),
                    const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equivalent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        l10n?.impactBasedOnSavedItems(savedCount) ??
                            'Based on $savedCount items saved',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  final List<MapEntry<String, double>> categories;

  const _CategoryBreakdownCard({required this.categories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ImpactStyle.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: _ImpactStyle.softShadow(isDark),
      ),
      child: Column(
        children: categories.asMap().entries.map((entry) {
          final idx = entry.key;
          final cat = entry.value.key;
          final amount = entry.value.value;

          IconData icon = Icons.fastfood_rounded;
          Color color = Colors.orange;
          final c = cat.toLowerCase();

          if (c.contains('veg') || c.contains('fruit')) { icon = Icons.eco_rounded; color = Colors.green; }
          else if (c.contains('meat') || c.contains('fish')) { icon = Icons.restaurant_rounded; color = Colors.redAccent; }
          else if (c.contains('dairy') || c.contains('milk')) { icon = Icons.egg_rounded; color = Colors.blueAccent; }
          else if (c.contains('snack') || c.contains('sweet')) { icon = Icons.cookie_rounded; color = Colors.purpleAccent; }
          else if (c.contains('carb') || c.contains('rice')) { icon = Icons.breakfast_dining_rounded; color = Colors.amber; }
          else if (c.contains('drink') || c.contains('coffee')) { icon = Icons.local_cafe_rounded; color = Colors.brown; }

          return Padding(
            padding: EdgeInsets.only(bottom: idx == categories.length - 1 ? 0 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    cat.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                Text(
                  '+\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.green),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatBentoCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatBentoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ImpactStyle.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: _ImpactStyle.softShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetImpactCard extends StatelessWidget {
  final String mascotAsset;
  final int fedItemCount;
  final double petQty;
  final double petShare;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _PetImpactCard({
    required this.mascotAsset,
    required this.fedItemCount,
    required this.petQty,
    required this.petShare,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _ImpactStyle.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
          boxShadow: _ImpactStyle.softShadow(isDark),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  mascotAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.pets, color: Colors.orange.shade300, size: 28);
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.impactEnjoyedLeftovers(petQty.toStringAsFixed(1)) ??
                        'Enjoyed ${petQty.toStringAsFixed(1)}kg of leftovers',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: petShare,
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<FlSpot> spots;
  final Map<int, String> labels;
  final Color color;
  final String unit;

  const _ChartCard({
    required this.spots,
    required this.labels,
    required this.color,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final double maxY = spots.isEmpty ? 5.0 : spots.fold(0.0, (m, s) => s.y > m ? s.y : m) * 1.2;
    final safeMaxY = maxY <= 0 ? 5.0 : maxY;

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: BoxDecoration(
        color: _ImpactStyle.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: _ImpactStyle.softShadow(isDark),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: safeMaxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
                color: colors.onSurface.withValues(alpha: 0.08),
                strokeWidth: 1,
                dashArray: [5, 5]
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < labels.length) {
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text(
                        labels[idx] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: spots.isEmpty ? 1 : (spots.length - 1).toDouble(),
          minY: 0,
          maxY: safeMaxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 12,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tooltipMargin: 16,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} $unit',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _ImpactStyle.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: _ImpactStyle.softShadow(isDark),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 48, color: colors.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text(
            l10n?.impactNoDataTitle ?? 'No data yet',
            style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.impactNoDataSubtitle ?? 'Start saving food to see your impact!',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SlidingRangeSelector extends StatelessWidget {
  final ImpactRange currentRange;
  final ValueChanged<ImpactRange> onChanged;

  const _SlidingRangeSelector({required this.currentRange, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedIndex = ImpactRange.values.indexOf(currentRange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: _alignmentForIndex(selectedIndex),
              child: FractionallySizedBox(
                widthFactor: 1 / ImpactRange.values.length,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Row(
              children: ImpactRange.values.map((r) {
                final isSelected = r == currentRange;
                return Expanded(
                  child: InkWell(
                    onTap: () => onChanged(r),
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _label(context, r),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Alignment _alignmentForIndex(int index) {
    if (ImpactRange.values.length <= 1) return Alignment.center;
    final t = index / (ImpactRange.values.length - 1);
    return Alignment(-1 + (2 * t), 0);
  }

  String _label(BuildContext context, ImpactRange r) {
    final l10n = AppLocalizations.of(context);
    switch(r) {
      case ImpactRange.week:
        return l10n?.impactRangeWeek ?? 'Week';
      case ImpactRange.month:
        return l10n?.impactRangeMonth ?? 'Month';
      case ImpactRange.year:
        return l10n?.impactRangeYear ?? 'Year';
    }
  }
}

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;

  const FadeInSlide({super.key, required this.child, required this.index, this.duration = const Duration(milliseconds: 600)});

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(curve);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fadeAnim, child: SlideTransition(position: _offsetAnim, child: widget.child));
  }
}







