import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // setEquals
import '../utils/app_haptics.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/inventory_repository.dart';
import '../utils/food_icon_mapping.dart';
import '../utils/app_locale.dart';
import '../l10n/app_localizations.dart';

const Color _reportPrimary = Color(0xFF1B78FF);
const Color _reportMint = Color(0xFFA3EEB1);
const Color _reportPeach = Color(0xFFFFCAB0);
const Color _reportLavender = Color(0xFFDCD6FF);
const Color _reportSoftRed = Color(0xFFFF8FA3);
const String _reportApiBaseUrl = 'https://project-study-bsh.vercel.app';

// NOTE: legacy comment cleaned.
class WeeklyData {
  final double moneySaved;
  final double moneyWasted; // NOTE: legacy comment cleaned.
  final double co2;
  final double heiScore;
  final bool isHeiLoading;
  final String heiSnapshot;
  final Map<String, double> macroSplit;
  final String dataSourceLabel;
  final Set<String> uniqueItems;
  final Map<String, int> categories;
  final Map<String, int> topItems; // top items
  final String contextSnapshot;

  String? aiInsight;
  List<Map<String, String>>? aiSuggestions;
  bool isAiLoading;

  final Set<String> analyzedItemsSnapshot;

  WeeklyData({
    required this.moneySaved,
    this.moneyWasted = 0.0,
    required this.co2,
    this.heiScore = 0.0,
    this.isHeiLoading = false,
    this.heiSnapshot = '',
    this.macroSplit = const {},
    this.dataSourceLabel = '',
    required this.uniqueItems,
    required this.categories,
    this.topItems = const {},
    this.aiInsight,
    this.aiSuggestions,
    this.isAiLoading = true,
    this.analyzedItemsSnapshot = const {},
    this.contextSnapshot = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'moneySaved': moneySaved,
      'moneyWasted': moneyWasted,
      'co2': co2,
      'heiScore': heiScore,
      'isHeiLoading': isHeiLoading,
      'heiSnapshot': heiSnapshot,
      'macroSplit': macroSplit,
      'dataSourceLabel': dataSourceLabel,
      'uniqueItems': uniqueItems.toList(),
      'categories': categories,
      'topItems': topItems,
      'aiInsight': aiInsight,
      'aiSuggestions': aiSuggestions,
      'analyzedItemsSnapshot': analyzedItemsSnapshot.toList(),
      'contextSnapshot': contextSnapshot,
    };
  }

  factory WeeklyData.fromJson(Map<String, dynamic> json) {
    return WeeklyData(
      moneySaved: (json['moneySaved'] as num?)?.toDouble() ?? 0.0,
      // NOTE: legacy comment cleaned.
      moneyWasted: (json['moneyWasted'] as num?)?.toDouble() ?? 0.0,
      co2: (json['co2'] as num).toDouble(),
      heiScore: (json['heiScore'] as num?)?.toDouble() ?? 0.0,
      isHeiLoading: json['isHeiLoading'] == true,
      heiSnapshot: json['heiSnapshot']?.toString() ?? '',
      macroSplit: (json['macroSplit'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
          const {},
      dataSourceLabel: json['dataSourceLabel']?.toString() ?? '',
      uniqueItems:
          (json['uniqueItems'] as List).map((e) => e.toString()).toSet(),
      categories: Map<String, int>.from(json['categories'] ?? {}),
      topItems: Map<String, int>.from(json['topItems'] ?? {}),
      aiInsight: json['aiInsight'],
      aiSuggestions: (json['aiSuggestions'] as List?)
          ?.map((e) => Map<String, String>.from(e))
          .toList(),
      analyzedItemsSnapshot: (json['analyzedItemsSnapshot'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          {},
      contextSnapshot: json['contextSnapshot']?.toString() ?? '',
      isAiLoading: false,
    );
  }
}

class WeeklyReportPage extends StatefulWidget {
  final InventoryRepository repo;
  final bool studentMode;

  const WeeklyReportPage({
    super.key,
    required this.repo,
    this.studentMode = false,
  });

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  final Map<int, WeeklyData> _memoryCache = {};
  int _weekOffset = 0; // 0 = this week
  final TextEditingController _thisWeekController = TextEditingController();
  final TextEditingController _nextWeekController = TextEditingController();
  String _nextWeekPreset = '';
  static const List<String> _contextPresets = [
    'Working out',
    'Finals week',
    'Traveling',
    'Hosting guests',
    'Busy work week',
  ];

  @override
  void initState() {
    super.initState();
    _loadWeekData(_weekOffset);
  }

  @override
  void dispose() {
    _thisWeekController.dispose();
    _nextWeekController.dispose();
    super.dispose();
  }

  // NOTE: legacy comment cleaned.
  Future<void> _loadWeekData(int offset) async {
    final now = DateTime.now();
    // NOTE: legacy comment cleaned.
    final endDate = now.subtract(Duration(days: 7 * offset));
    final startDate = endDate.subtract(const Duration(days: 7));
    final nextWeekStart = endDate;
    final nextWeekEnd = endDate.add(const Duration(days: 7));

    // NOTE: legacy comment cleaned.
    final events = widget.repo.impactEvents.where((e) {
      return e.date.isAfter(startDate) && e.date.isBefore(endDate);
    }).toList();

    double moneySaved = 0;
    double moneyWasted = 0;
    double co2 = 0;
    final currentUniqueItems = <String>{};
    final catCounts = <String, int>{};
    final itemFreq = <String, int>{}; // NOTE: legacy comment cleaned.
    final rawItemNamesForAi = <String>[];

    for (var e in events) {
      // NOTE: legacy comment cleaned.
      if (e.type == ImpactType.eaten || e.type == ImpactType.fedToPet) {
        moneySaved += e.moneySaved;
        co2 += e.co2Saved;

        final name = e.itemName ?? 'Unknown Item';
        if (e.itemName != null && e.itemName!.isNotEmpty) {
          currentUniqueItems.add(name);
          rawItemNamesForAi.add(name);

          // NOTE: legacy comment cleaned.
          itemFreq[name] = (itemFreq[name] ?? 0) + 1;

          // NOTE: legacy comment cleaned.
          final key = _inferCategory(e.itemCategory, name);
          catCounts[key] = (catCounts[key] ?? 0) + 1;
        }
      }
      // NOTE: legacy comment cleaned.
      else if (e.type == ImpactType.trash) {
        // NOTE: legacy comment cleaned.
        // NOTE: legacy comment cleaned.
        moneyWasted += e.moneySaved;
      }
    }

    // NOTE: legacy comment cleaned.
    final sortedTopItems = Map.fromEntries(
        itemFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

    // NOTE: legacy comment cleaned.
    WeeklyData? cachedData = _memoryCache[offset];
    if (cachedData == null) {
      cachedData = await _loadFromDisk(offset);
      if (cachedData != null) {
        _memoryCache[offset] = cachedData;
      }
    }

    final heiSnapshot = _buildHeiSnapshot(itemFreq);

    // NOTE: legacy comment cleaned.
    final plannedMealsThisWeek = _buildPlannedMealsPayload(startDate, endDate);
    final plannedMealsNextWeek =
        _buildPlannedMealsPayload(nextWeekStart, nextWeekEnd);
    final plannedSnapshot =
        _buildPlannedMealsSnapshot(plannedMealsThisWeek, plannedMealsNextWeek);
    final contextSnapshot = _buildAiContextSnapshot(plannedSnapshot);
    bool canUseCachedAi = false;
    if (offset > 0 && cachedData?.aiInsight != null) {
      canUseCachedAi = true;
    } else if (cachedData != null &&
        cachedData.aiInsight != null &&
        setEquals(cachedData.analyzedItemsSnapshot, currentUniqueItems) &&
        cachedData.contextSnapshot == contextSnapshot) {
      canUseCachedAi = true;
    }

    double heiScore = cachedData?.heiScore ?? 0.0;
    bool heiLoading = false;
    Map<String, double> macroSplit = cachedData?.macroSplit ?? const {};
    String dataSourceLabel = cachedData?.dataSourceLabel ?? '';
    if (currentUniqueItems.isNotEmpty) {
      final hasCachedHei =
          cachedData != null && cachedData.heiSnapshot.isNotEmpty;
      if (offset > 0 && hasCachedHei) {
        heiScore = cachedData.heiScore;
        macroSplit = cachedData.macroSplit;
        dataSourceLabel = cachedData.dataSourceLabel;
        heiLoading = false;
      } else if (cachedData != null && cachedData.heiSnapshot == heiSnapshot) {
        heiScore = cachedData.heiScore;
        macroSplit = cachedData.macroSplit;
        dataSourceLabel = cachedData.dataSourceLabel;
      } else {
        heiLoading = true;
      }
    }

    // NOTE: legacy comment cleaned.
    final newData = WeeklyData(
      moneySaved: moneySaved,
      moneyWasted: moneyWasted,
      co2: co2,
      heiScore: heiScore,
      isHeiLoading: heiLoading,
      heiSnapshot: heiSnapshot,
      macroSplit: macroSplit,
      dataSourceLabel: dataSourceLabel,
      uniqueItems: currentUniqueItems,
      categories: catCounts,
      topItems: sortedTopItems,
      aiInsight: canUseCachedAi ? cachedData!.aiInsight : cachedData?.aiInsight,
      aiSuggestions: canUseCachedAi
          ? cachedData!.aiSuggestions
          : cachedData?.aiSuggestions,
      isAiLoading: !canUseCachedAi && currentUniqueItems.isNotEmpty,
      analyzedItemsSnapshot:
          canUseCachedAi ? cachedData!.analyzedItemsSnapshot : const {},
      contextSnapshot: contextSnapshot,
    );

    _memoryCache[offset] = newData;
    if (mounted) setState(() {});

    if (heiLoading) {
      await _updateHeiScore(offset, itemFreq, heiSnapshot);
    }

    // NOTE: legacy comment cleaned.
    if (!canUseCachedAi && currentUniqueItems.isNotEmpty) {
      await _fetchAiInsight(
        offset,
        rawItemNamesForAi,
        currentUniqueItems,
        itemFreq,
        contextSnapshot,
        plannedMealsThisWeek,
        plannedMealsNextWeek,
      );
    } else if (currentUniqueItems.isEmpty) {
      _memoryCache[offset] = WeeklyData(
        moneySaved: moneySaved,
        moneyWasted: moneyWasted,
        co2: co2,
        heiScore: 0,
        isHeiLoading: false,
        heiSnapshot: '',
        macroSplit: const {},
        dataSourceLabel: '',
        uniqueItems: {},
        categories: {},
        topItems: {},
        aiInsight: "No meals logged this week. Time to cook!",
        aiSuggestions: [],
        isAiLoading: false,
      );
      if (mounted) setState(() {});
    }
  }

  Future<WeeklyData?> _loadFromDisk(int offset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'weekly_report_v2_$offset'; // NOTE: legacy comment cleaned.
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        return WeeklyData.fromJson(jsonDecode(jsonString));
      }
    } catch (e) {
      debugPrint("Cache load error: $e");
    }
    return null;
  }

  Future<void> _saveToDisk(int offset, WeeklyData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'weekly_report_v2_$offset';
      await prefs.setString(key, jsonEncode(data.toJson()));
    } catch (e) {
      debugPrint("Cache save error: $e");
    }
  }

  Future<void> _fetchAiInsight(
    int offset,
    List<String> itemsList,
    Set<String> itemsSet,
    Map<String, int> itemFreq,
    String contextSnapshot,
    List<Map<String, dynamic>> plannedMealsThisWeek,
    List<Map<String, dynamic>> plannedMealsNextWeek,
  ) async {
    try {
      final uri = Uri.parse('https://project-study-bsh.vercel.app/api/recipe');
      final locale = AppLocale.fromContext(context);
      final historyContext = _buildWeeklyComparisonContext(weekOffset: offset);
      final consumptionCounts = itemFreq.map((k, v) => MapEntry(k, v));
      final weekContext = _buildWeekContext();
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept-Language': locale,
          'X-App-Locale': locale,
        },
        body: jsonEncode({
          'action': 'analyze_diet',
          'locale': locale,
          'consumed': itemsList,
          'consumptionCounts': consumptionCounts,
          'plannedMealsThisWeek': plannedMealsThisWeek,
          'plannedMealsNextWeek': plannedMealsNextWeek,
          'weekContext': weekContext,
          'studentMode': widget.studentMode,
          'history': historyContext,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = data['suggestions'] as List? ?? [];

        if (mounted) {
          setState(() {
            final currentBase = _memoryCache[offset]!;
            final updatedData = WeeklyData(
              moneySaved: currentBase.moneySaved,
              moneyWasted: currentBase.moneyWasted,
              co2: currentBase.co2,
              heiScore: currentBase.heiScore,
              isHeiLoading: currentBase.isHeiLoading,
              heiSnapshot: currentBase.heiSnapshot,
              macroSplit: currentBase.macroSplit,
              dataSourceLabel: currentBase.dataSourceLabel,
              uniqueItems: currentBase.uniqueItems,
              categories: currentBase.categories,
              topItems: currentBase.topItems,
              aiInsight: data['insight'],
              aiSuggestions: list
                  .map((e) => {
                        'name': e['name']?.toString() ?? '',
                        'category': e['category']?.toString() ?? 'general',
                        'reason': e['reason']?.toString() ?? '',
                      })
                  .toList(),
              isAiLoading: false,
              analyzedItemsSnapshot: itemsSet,
              contextSnapshot: contextSnapshot,
            );

            _memoryCache[offset] = updatedData;
            _saveToDisk(offset, updatedData);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final current = _memoryCache[offset];
          if (current != null) {
            _memoryCache[offset] = WeeklyData(
              moneySaved: current.moneySaved,
              moneyWasted: current.moneyWasted,
              co2: current.co2,
              heiScore: current.heiScore,
              isHeiLoading: current.isHeiLoading,
              heiSnapshot: current.heiSnapshot,
              macroSplit: current.macroSplit,
              dataSourceLabel: current.dataSourceLabel,
              uniqueItems: current.uniqueItems,
              categories: current.categories,
              topItems: current.topItems,
              aiInsight: current.aiInsight ?? "Could not load AI insight.",
              aiSuggestions: current.aiSuggestions ?? [],
              isAiLoading: false,
              analyzedItemsSnapshot: current.analyzedItemsSnapshot,
              contextSnapshot: current.contextSnapshot,
            );
          }
        });
      }
    }
  }

  // ... Date pickers and helpers (Same as before) ...
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(Duration(days: 7 * _weekOffset)),
      firstDate: firstDate,
      lastDate: now,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _reportPrimary)),
        child: child!,
      ),
    );
    if (picked != null) {
      final diff = now.difference(picked).inDays;
      final newOffset = (diff / 7).floor();
      if (newOffset != _weekOffset) {
        setState(() => _weekOffset = newOffset);
        _loadWeekData(newOffset);
      }
    }
  }

  void _changeWeek(int delta) {
    final newOffset = (_weekOffset + delta).clamp(0, 52);
    if (newOffset == _weekOffset) return;
    setState(() => _weekOffset = newOffset);
    _loadWeekData(newOffset);
  }

  void _resetToCurrentWeek() {
    if (_weekOffset == 0) return;
    AppHaptics.selection();
    setState(() => _weekOffset = 0);
    _loadWeekData(0);
  }

  String _inferCategory(String? cat, String name) {
    final c = (cat ?? '').toLowerCase();
    final n = name.toLowerCase();
    if (c.contains('veg') ||
        c.contains('salad') ||
        n.contains('onion') ||
        n.contains('carrot') ||
        n.contains('spinach')) return 'Veggies';
    if (c.contains('fruit') ||
        n.contains('banana') ||
        n.contains('apple') ||
        n.contains('berry')) return 'Fruits';
    if (c.contains('meat') ||
        c.contains('fish') ||
        c.contains('egg') ||
        n.contains('beef') ||
        n.contains('chicken')) return 'Protein';
    if (c.contains('dairy') || c.contains('cheese') || c.contains('milk'))
      return 'Dairy';
    if (c.contains('carb') ||
        c.contains('bread') ||
        c.contains('rice') ||
        c.contains('pasta')) return 'Carbs';
    return 'Other';
  }

  String _buildHeiSnapshot(Map<String, int> itemFreq) {
    if (itemFreq.isEmpty) return '';
    final entries = itemFreq.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  List<String> _expandHeiItems(Map<String, int> itemFreq) {
    final out = <String>[];
    for (final entry in itemFreq.entries) {
      for (var i = 0; i < entry.value; i++) {
        out.add(entry.key);
      }
    }
    return out;
  }

  Future<void> _updateHeiScore(
      int offset, Map<String, int> itemFreq, String heiSnapshot) async {
    try {
      final result = await _fetchHeiScoreFromBackend(itemFreq);
      if (result == null) return;
      final current = _memoryCache[offset];
      if (current == null) return;
      final updated = WeeklyData(
        moneySaved: current.moneySaved,
        moneyWasted: current.moneyWasted,
        co2: current.co2,
        heiScore: result.score,
        isHeiLoading: false,
        heiSnapshot: heiSnapshot,
        macroSplit: result.macroSplit,
        dataSourceLabel: result.dataSourceLabel,
        uniqueItems: current.uniqueItems,
        categories: current.categories,
        topItems: current.topItems,
        aiInsight: current.aiInsight,
        aiSuggestions: current.aiSuggestions,
        isAiLoading: current.isAiLoading,
        analyzedItemsSnapshot: current.analyzedItemsSnapshot,
        contextSnapshot: current.contextSnapshot,
      );
      _memoryCache[offset] = updated;
      if (mounted) setState(() {});
      await _saveToDisk(offset, updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          final current = _memoryCache[offset];
          if (current != null) {
            final fallback = _computeHeiScore(
                items: _expandHeiItems(itemFreq), categories: const {});
            _memoryCache[offset] = WeeklyData(
              moneySaved: current.moneySaved,
              moneyWasted: current.moneyWasted,
              co2: current.co2,
              heiScore: fallback,
              isHeiLoading: false,
              heiSnapshot: current.heiSnapshot,
              macroSplit: current.macroSplit,
              dataSourceLabel: current.dataSourceLabel,
              uniqueItems: current.uniqueItems,
              categories: current.categories,
              topItems: current.topItems,
              aiInsight: current.aiInsight,
              aiSuggestions: current.aiSuggestions,
              isAiLoading: current.isAiLoading,
              analyzedItemsSnapshot: current.analyzedItemsSnapshot,
              contextSnapshot: current.contextSnapshot,
            );
          }
        });
      }
    }
  }

  Future<_HeiApiResult?> _fetchHeiScoreFromBackend(
      Map<String, int> itemFreq) async {
    if (itemFreq.isEmpty) return null;
    final uri = Uri.parse('$_reportApiBaseUrl/api/hei-score');
    final locale = AppLocale.fromContext(context);
    final items =
        itemFreq.entries.map((e) => {'name': e.key, 'count': e.value}).toList();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': locale,
        'X-App-Locale': locale,
      },
      body: jsonEncode({'items': items, 'language': locale, 'locale': locale}),
    );
    if (resp.statusCode != 200) {
      throw Exception('HEI API error: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final score = data['heiScore'];
    final macro = (data['macroSplit'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
        const <String, double>{};
    final label = data['dataSourceLabel']?.toString() ?? '';
    if (score is num) {
      return _HeiApiResult(
        score: score.toDouble(),
        macroSplit: macro,
        dataSourceLabel: label,
      );
    }
    return null;
  }

  double _computeHeiScore({
    required List<String> items,
    required Map<String, int> categories,
  }) {
    if (items.isEmpty) return 0;
    final total = items.length.toDouble();
    int fruits = 0;
    int wholeFruits = 0;
    int veggies = 0;
    int greensBeans = 0;
    int wholeGrains = 0;
    int refinedGrains = 0;
    int dairy = 0;
    int totalProtein = 0;
    int seafoodPlant = 0;
    int addedSugars = 0;
    int sodium = 0;
    int satFat = 0;
    int healthyFats = 0;
    int saturatedFats = 0;

    bool containsAny(String v, List<String> needles) {
      for (final n in needles) {
        if (v.contains(n)) return true;
      }
      return false;
    }

    for (final raw in items) {
      final name = raw.toLowerCase();
      final isFruit = containsAny(name, [
        'apple',
        'banana',
        'berry',
        'orange',
        'grape',
        'pear',
        'peach',
        'mango',
        'pineapple',
        'melon',
        'kiwi',
      ]);
      final isJuice = containsAny(name, ['juice', 'smoothie']);
      final isVeg = containsAny(name, [
        'broccoli',
        'spinach',
        'kale',
        'lettuce',
        'salad',
        'carrot',
        'tomato',
        'pepper',
        'onion',
        'cabbage',
        'cucumber',
        'zucchini',
        'eggplant',
      ]);
      final isGreens =
          containsAny(name, ['spinach', 'kale', 'lettuce', 'arugula', 'chard']);
      final isBeans = containsAny(name, ['bean', 'lentil', 'chickpea', 'pea']);
      final isWholeGrain = containsAny(name, [
        'whole',
        'oat',
        'oats',
        'quinoa',
        'barley',
        'brown rice',
        'whole wheat'
      ]);
      final isRefinedGrain = containsAny(name, [
        'white bread',
        'pasta',
        'noodle',
        'white rice',
        'flour',
        'cracker',
        'pastry'
      ]);
      final isDairy = containsAny(name, ['milk', 'cheese', 'yogurt']);
      final isProtein = containsAny(name, [
        'beef',
        'chicken',
        'pork',
        'egg',
        'tofu',
        'tempeh',
        'fish',
        'salmon',
        'tuna',
        'shrimp'
      ]);
      final isSeafoodPlant = containsAny(name, [
        'fish',
        'salmon',
        'tuna',
        'shrimp',
        'tofu',
        'tempeh',
        'bean',
        'lentil',
        'chickpea',
        'nut',
        'seed'
      ]);
      final isAddedSugar = containsAny(name, [
        'sugar',
        'soda',
        'candy',
        'cookie',
        'cake',
        'dessert',
        'ice cream',
        'sweet'
      ]);
      final isHighSodium = containsAny(name, [
        'bacon',
        'sausage',
        'ham',
        'deli',
        'instant',
        'ramen',
        'chip',
        'canned',
        'soy sauce',
        'salted'
      ]);
      final isSatFat = containsAny(name,
          ['butter', 'cream', 'cheese', 'bacon', 'sausage', 'beef', 'pork']);
      final isHealthyFat =
          containsAny(name, ['olive', 'avocado', 'nut', 'seed', 'salmon']);

      if (isFruit) {
        fruits += 1;
        if (!isJuice) wholeFruits += 1;
      }
      if (isVeg) veggies += 1;
      if (isGreens || isBeans) greensBeans += 1;
      if (isWholeGrain) wholeGrains += 1;
      if (isRefinedGrain) refinedGrains += 1;
      if (isDairy) dairy += 1;
      if (isProtein) totalProtein += 1;
      if (isSeafoodPlant) seafoodPlant += 1;
      if (isAddedSugar) addedSugars += 1;
      if (isHighSodium) sodium += 1;
      if (isSatFat) {
        satFat += 1;
        saturatedFats += 1;
      }
      if (isHealthyFat) healthyFats += 1;
    }

    double scoreAdequacy(int count, double targetShare, double maxScore) {
      final target = total * targetShare;
      if (target <= 0) return 0;
      final ratio = (count / target).clamp(0.0, 1.0);
      return maxScore * ratio;
    }

    double scoreModeration(
        int badCount, double maxScore, double minShare, double maxShare) {
      final share = badCount / total;
      if (share <= minShare) return maxScore;
      if (share >= maxShare) return 0;
      final ratio = (maxShare - share) / (maxShare - minShare);
      return maxScore * ratio;
    }

    final totalFruitsScore = scoreAdequacy(fruits, 0.15, 5);
    final wholeFruitsScore = scoreAdequacy(wholeFruits, 0.1, 5);
    final totalVegScore = scoreAdequacy(veggies, 0.2, 5);
    final greensBeansScore = scoreAdequacy(greensBeans, 0.07, 5);
    final wholeGrainsScore = scoreAdequacy(wholeGrains, 0.1, 10);
    final dairyScore = scoreAdequacy(dairy, 0.1, 10);
    final totalProteinScore = scoreAdequacy(totalProtein, 0.15, 5);
    final seafoodPlantScore = scoreAdequacy(seafoodPlant, 0.07, 5);

    final refinedGrainsScore = scoreModeration(refinedGrains, 10, 0.1, 0.35);
    final sodiumScore = scoreModeration(sodium, 10, 0.05, 0.2);
    final addedSugarsScore = scoreModeration(addedSugars, 10, 0.05, 0.2);
    final satFatScore = scoreModeration(satFat, 10, 0.08, 0.25);

    final fattyAcidRatio = saturatedFats == 0
        ? (healthyFats > 0 ? 3.0 : 0.0)
        : healthyFats / saturatedFats;
    final fattyAcidsScore = (() {
      if (fattyAcidRatio >= 2.5) return 10.0;
      if (fattyAcidRatio <= 1.2) return 0.0;
      return 10.0 * ((fattyAcidRatio - 1.2) / (2.5 - 1.2));
    })();

    final totalScore = totalFruitsScore +
        wholeFruitsScore +
        totalVegScore +
        greensBeansScore +
        wholeGrainsScore +
        dairyScore +
        totalProteinScore +
        seafoodPlantScore +
        refinedGrainsScore +
        sodiumScore +
        addedSugarsScore +
        satFatScore +
        fattyAcidsScore;

    return totalScore.clamp(0.0, 100.0);
  }

  Map<String, dynamic> _buildWeeklyComparisonContext(
      {required int weekOffset}) {
    final now = DateTime.now();
    final endThisWeek = now.subtract(Duration(days: 7 * weekOffset));
    final startThisWeek = endThisWeek.subtract(const Duration(days: 7));
    final startLastWeek = startThisWeek.subtract(const Duration(days: 7));

    final thisWeek = _aggregateWindow(startThisWeek, endThisWeek);
    final lastWeek = _aggregateWindow(startLastWeek, startThisWeek);

    return {
      'thisWeek': thisWeek,
      'lastWeek': lastWeek,
    };
  }

  Map<String, dynamic> _aggregateWindow(DateTime start, DateTime end) {
    final itemCounts = <String, int>{};
    final categoryCounts = <String, int>{};
    var totalMeals = 0;

    for (final e in widget.repo.impactEvents) {
      if (e.date.isBefore(start) || e.date.isAfter(end)) continue;
      if (e.type != ImpactType.eaten && e.type != ImpactType.fedToPet) continue;
      final name = (e.itemName ?? '').trim();
      if (name.isEmpty) continue;
      totalMeals += 1;
      itemCounts[name] = (itemCounts[name] ?? 0) + 1;
      final cat = _inferCategory(e.itemCategory, name);
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    final topItems = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'totalMeals': totalMeals,
      'uniqueItems': itemCounts.keys.length,
      'topItems': topItems
          .take(8)
          .map((e) => {'name': e.key, 'count': e.value})
          .toList(),
      'categoryMix': categoryCounts,
    };
  }

  String _getDateRangeForOffset(int offset) {
    final now = DateTime.now();
    final end = now.subtract(Duration(days: 7 * offset));
    final start = end.subtract(const Duration(days: 7));
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }

  Future<void> _addToShoppingList(String name, String category) async {
    final l10n = AppLocalizations.of(context);
    final newItem = ShoppingItem(
      id: const Uuid().v4(),
      name: name,
      category: category,
      isChecked: false,
    );
    await widget.repo.saveShoppingItem(newItem);
    if (!mounted) return;
    AppHaptics.success();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _reportPrimary,
        content: Text(l10n?.weeklyAddedToShoppingList ?? 'Added to shopping list.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _restockContextSnapshot() {
    return '${_thisWeekController.text.trim()}|${_nextWeekController.text.trim()}';
  }

  String _buildAiContextSnapshot(String plannedSnapshot) {
    return '${_restockContextSnapshot()}|planned:$plannedSnapshot';
  }

  List<Map<String, dynamic>> _buildPlannedMealsPayload(
      DateTime start, DateTime end) {
    final plans = widget.repo.getMealPlansForRange(start, end);
    plans.sort((a, b) {
      final dateCompare = a.planDate.compareTo(b.planDate);
      if (dateCompare != 0) return dateCompare;
      return a.slot.compareTo(b.slot);
    });
    return plans
        .map((p) => {
              'date': p.planDate.toIso8601String().substring(0, 10),
              'slot': p.slot,
              'mealName': p.mealName,
              'recipeName': p.recipeName,
              'itemIds': p.itemIds.toList(),
            })
        .toList();
  }

  String _buildPlannedMealsSnapshot(
    List<Map<String, dynamic>> thisWeek,
    List<Map<String, dynamic>> nextWeek,
  ) {
    String encode(List<Map<String, dynamic>> list) {
      return list.map((e) {
        final items = (e['itemIds'] as List? ?? []).join(',');
        return '${e['date']}|${e['slot']}|${e['recipeName'] ?? ''}|$items';
      }).join(';');
    }

    return '${encode(thisWeek)}||${encode(nextWeek)}';
  }

  Map<String, String> _buildWeekContext() {
    return {
      'thisWeek': _thisWeekController.text.trim(),
      'nextWeek': _nextWeekController.text.trim(),
    };
  }

  Widget _buildContextInputCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget buildPresetRow({
      required String selected,
      required ValueChanged<String> onSelected,
    }) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _contextPresets.map((preset) {
          final isSelected = selected == preset;
          return GestureDetector(
            onTap: () => onSelected(preset),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _reportPrimary
                    : colors.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                preset,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    Widget buildInputRow({
      required IconData icon,
      required TextEditingController controller,
      required String hintText,
      required VoidCallback onSubmit,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: _reportPrimary.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: _reportPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              onPressed: onSubmit,
              icon: const Icon(Icons.arrow_upward_rounded,
                  size: 18, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: _reportPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildPresetRow(
          selected: _nextWeekPreset,
          onSelected: (preset) {
            setState(() {
              _nextWeekPreset = preset;
              _nextWeekController.text = preset;
            });
          },
        ),
        const SizedBox(height: 12),
        buildInputRow(
          icon: Icons.edit_note,
          controller: _nextWeekController,
          hintText: 'Next week, I will be...',
          onSubmit: () => _loadWeekData(_weekOffset),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _memoryCache[_weekOffset] ??
        WeeklyData(
          moneySaved: 0,
          co2: 0,
          heiScore: 0,
          isHeiLoading: false,
          heiSnapshot: '',
          macroSplit: const {},
          dataSourceLabel: '',
          uniqueItems: {},
          categories: {},
        );
    final prevData = _memoryCache[_weekOffset + 1];
    final heiDelta =
        (prevData == null || data.isHeiLoading || prevData.isHeiLoading)
            ? null
            : data.heiScore - prevData.heiScore;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final currentRange = _getDateRangeForOffset(_weekOffset);
    final prevRange = _getDateRangeForOffset(_weekOffset + 1);
    final nextRange =
        _weekOffset > 0 ? _getDateRangeForOffset(_weekOffset - 1) : '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Weekly Wrap-Up',
          style:
              TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          _WeekSelector(
            dateRange: currentRange,
            prevRange: prevRange,
            nextRange: nextRange,
            offset: _weekOffset,
            onPrev: () => _changeWeek(1),
            onNext: () => _changeWeek(-1),
            onTapDate: _pickDate,
            onReset: _resetToCurrentWeek,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InsightHeroCard(
                    insight: data.aiInsight,
                    isLoading: data.isAiLoading,
                  ),

                  const SizedBox(height: 24),

                  // NOTE: legacy comment cleaned.
                  _HeiScorecard(
                    score: data.heiScore,
                    isLoading: data.isHeiLoading,
                    deltaFromLastWeek: heiDelta,
                  ),
                  const SizedBox(height: 16),
                  _MacroSplitCard(
                    macroSplit: data.macroSplit,
                    dataSourceLabel: data.dataSourceLabel,
                    isLoading: data.isHeiLoading,
                  ),

                  const SizedBox(height: 24),

                  // Diet Breakdown
                  if (data.categories.isNotEmpty) ...[
                    Text(
                      'Diet Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DietCompositionCard(data: data.categories),
                    const SizedBox(height: 24),
                  ],

                  // NOTE: legacy comment cleaned.
                  if (data.topItems.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Top Favorites',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          '${data.uniqueItems.length} items total',
                          style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _TopItemsList(
                        topItems: data.topItems, allItems: data.uniqueItems),
                    const SizedBox(height: 24),
                  ],

                  // Smart Restock
                  Text(
                    'Smart Restock',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildContextInputCard(context),
                  const SizedBox(height: 16),

                  if (data.isAiLoading)
                    const _RestockLoadingSkeleton()
                  else if (data.aiSuggestions == null ||
                      data.aiSuggestions!.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        'No suggestions needed. You are doing great!',
                        style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.6)),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.aiSuggestions!.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = data.aiSuggestions![index];
                        return _RestockCard(
                          name: item['name']!,
                          reason: item['reason']!,
                          onAdd: () => _addToShoppingList(
                              item['name']!, item['category']!),
                        );
                      },
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== Components ==================

class _HeiScorecard extends StatelessWidget {
  final double score;
  final bool isLoading;
  final double? deltaFromLastWeek;

  const _HeiScorecard({
    required this.score,
    required this.isLoading,
    required this.deltaFromLastWeek,
  });

  void _showHeiInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n?.weeklyHeiExplainedTitle ?? 'HEI-2015 Explained',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.weeklyHeiExplainedIntro ??
                    'The Healthy Eating Index (HEI-2015) is a 0-100 score that measures how well a diet aligns with the Dietary Guidelines for Americans.',
                style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.8),
                    height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                l10n?.weeklyHeiHowComputeTitle ?? 'How we compute it',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: colors.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                l10n?.weeklyHeiHowComputeBody ??
                    'We estimate HEI components using USDA FoodData Central nutrients and your logged foods. Components include:',
                style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.7),
                    height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.weeklyHeiComponentsList ??
                    '- Fruits (total and whole)\n'
                        '- Vegetables (total and greens/beans)\n'
                        '- Whole grains\n'
                        '- Dairy\n'
                        '- Total protein and seafood/plant protein\n'
                        '- Fatty acids ratio\n'
                        '- Moderation: refined grains, sodium, added sugars, saturated fat',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n?.weeklyHeiMorePoints ??
                    'More points = better balance. We normalize per 1,000 kcal where applicable and use HEI-2015 scoring standards.',
                style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.7),
                    height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            child: Text(l10n?.weeklyGotIt ?? 'Got it'),
          ),
        ],
      ),
    );
  }

  String _label(BuildContext context, double score) {
    final l10n = AppLocalizations.of(context);
    if (score >= 80) return l10n?.weeklyHeiLabelExcellent ?? 'Excellent';
    if (score >= 60) return l10n?.weeklyHeiLabelGood ?? 'Good';
    if (score >= 40) return l10n?.weeklyHeiLabelFair ?? 'Fair';
    return l10n?.weeklyHeiLabelNeedsWork ?? 'Needs Work';
  }

  Color _labelColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (isLoading) return colors.primary;
    if (score >= 80) return Colors.green;
    if (score >= 60) return colors.primary;
    if (score >= 40) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final normalized = (score / 100).clamp(0.0, 1.0);
    final displayScore = isLoading ? '--' : score.toStringAsFixed(0);
    final delta = deltaFromLastWeek;
    final deltaColor = delta == null
        ? colors.onSurface.withValues(alpha: 0.5)
        : (delta >= 0 ? Colors.green : Colors.redAccent);
    final deltaText = (delta == null)
        ? 'vs last week: -'
        : 'vs last week: ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _reportPrimary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Healthy Eating Index',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showHeiInfo(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  text: displayScore,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    TextSpan(
                      text: '/100',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FractionallySizedBox(
                  widthFactor: normalized,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _labelColor(context),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: _labelColor(context).withValues(alpha: 0.35),
                          blurRadius: 12,
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isLoading ? 'Calculating...' : _label(context, score),
                style: TextStyle(
                  fontSize: 11,
                  color: _labelColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (delta != null)
                    Icon(
                      delta >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 12,
                      color: deltaColor,
                    ),
                  if (delta != null) const SizedBox(width: 4),
                  Text(
                    deltaText,
                    style: TextStyle(
                      fontSize: 10,
                      color: deltaColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'USDA-based HEI-2015',
                style: TextStyle(
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: isLoading ? null : normalized,
                  strokeWidth: 6,
                  backgroundColor: colors.onSurface.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(_labelColor(context)),
                ),
                Icon(Icons.monitor_heart, color: _labelColor(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroSplitCard extends StatelessWidget {
  final Map<String, double> macroSplit;
  final String dataSourceLabel;
  final bool isLoading;

  const _MacroSplitCard({
    required this.macroSplit,
    required this.dataSourceLabel,
    required this.isLoading,
  });

  double _getPct(String key) => (macroSplit[key] ?? 0).clamp(0, 100);

  String _formatG(String key) => (macroSplit[key] ?? 0).toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final protein = _getPct('proteinKcalPct');
    final carbs = _getPct('carbsKcalPct');
    final fat = _getPct('fatKcalPct');
    final sourceLabel =
        dataSourceLabel.isEmpty ? 'USDA FoodData Central' : dataSourceLabel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _reportPrimary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macro Split',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const _ShimmerBlock(width: double.infinity, height: 12)
          else if (macroSplit.isEmpty)
            Text(
              l10n?.weeklyMacrosNotEnoughData ?? 'Not enough data to calculate macros.',
              style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.6), fontSize: 12),
            )
          else ...[
            _MacroRow(
              label: l10n?.weeklyMacroProtein ?? 'Protein',
              color: _reportPrimary,
              pct: protein,
              grams: _formatG('proteinG'),
            ),
            const SizedBox(height: 10),
            _MacroRow(
              label: l10n?.weeklyMacroCarbs ?? 'Carbs',
              color: _reportMint,
              pct: carbs,
              grams: _formatG('carbsG'),
            ),
            const SizedBox(height: 10),
            _MacroRow(
              label: l10n?.weeklyMacroFat ?? 'Fat',
              color: _reportPeach,
              pct: fat,
              grams: _formatG('fatG'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n?.weeklyDataSource(sourceLabel) ?? 'Data source: $sourceLabel',
            style: TextStyle(
              fontSize: 10,
              color: colors.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final Color color;
  final double pct;
  final String grams;

  const _MacroRow({
    required this.label,
    required this.color,
    required this.pct,
    required this.grams,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (pct / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.35), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${pct.toStringAsFixed(0)}% - ${grams}g',
          style: TextStyle(
              fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

class _TopItemsList extends StatelessWidget {
  final Map<String, int> topItems; // top items
  final Set<String> allItems;

  const _TopItemsList({required this.topItems, required this.allItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final top3 = topItems.entries.take(3).toList();

    return Column(
      children: [
        ...top3.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final badgeColor = idx == 0
              ? _reportPrimary
              : idx == 1
                  ? _reportPrimary.withValues(alpha: 0.8)
                  : _reportPrimary.withValues(alpha: 0.6);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _reportPrimary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: _WeeklyItemIcon(name: item.key),
                    ),
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.cardColor, width: 2),
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.key,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: colors.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Used ${item.value} times',
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          );
        }),
        if (allItems.length > 3)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            title: Text(
              'View all ${allItems.length} items',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _reportPrimary),
            ),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allItems
                    .skip(3)
                    .map((name) => Chip(
                          label: Text(name),
                          backgroundColor: theme.cardColor,
                          side: BorderSide(color: theme.dividerColor),
                          labelStyle: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.7)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
      ],
    );
  }
}

class _WeeklyItemIcon extends StatelessWidget {
  final String name;

  const _WeeklyItemIcon({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final assetPath = foodIconAssetForName(name);
    return Image.asset(
      assetPath,
      width: 30,
      height: 30,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        final fallback =
            name.trim().isEmpty ? '?' : name.characters.first.toUpperCase();
        return Text(
          fallback,
          style:
              TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface),
        );
      },
    );
  }
}

class _WeekSelector extends StatelessWidget {
  final String dateRange;
  final String prevRange;
  final String nextRange;
  final int offset;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapDate;
  final VoidCallback onReset;

  const _WeekSelector({
    required this.dateRange,
    required this.prevRange,
    required this.nextRange,
    required this.offset,
    required this.onPrev,
    required this.onNext,
    required this.onTapDate,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _reportPrimary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _WeekChip(
              label: prevRange.isEmpty ? (l10n?.weeklyPrev ?? 'Prev') : prevRange,
              enabled: true,
              onTap: onPrev,
              isActive: false,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _WeekChip(
              label: dateRange,
              enabled: true,
              onTap: onTapDate,
              isActive: true,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _WeekChip(
              label: nextRange.isEmpty ? (l10n?.weeklyNext ?? 'Next') : nextRange,
              enabled: offset > 0,
              onTap: onNext,
              isActive: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isActive;
  final VoidCallback onTap;

  const _WeekChip({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bgColor = isActive ? _reportPrimary : Colors.transparent;
    final textColor = isActive
        ? Colors.white
        : colors.onSurface.withValues(alpha: enabled ? 0.6 : 0.3);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _reportPrimary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: textColor,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _InsightHeroCard extends StatelessWidget {
  final String? insight;
  final bool isLoading;

  const _InsightHeroCard({this.insight, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primary = colors.primary;
    final primaryDark = Color.lerp(primary, Colors.black, 0.25) ?? primary;
    final primaryLight = Color.lerp(primary, Colors.white, 0.2) ?? primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryDark, primary, primaryLight],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child:
                    const Icon(Icons.smart_toy, color: Colors.white, size: 26),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'AI Insight',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading) ...[
            const _ShimmerBlock(width: 200, height: 16, isDark: true),
            const SizedBox(height: 8),
            const _ShimmerBlock(width: 150, height: 16, isDark: true),
          ] else ...[
            Text(
              'Great job!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              insight ?? 'Analysis failed. Check your connection.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            isLoading ? 'ANALYZING...' : 'WEEKLY AI SUMMARY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 1,
            ),
          ),
          if (colors.brightness == Brightness.light) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RestockLoadingSkeleton extends StatelessWidget {
  const _RestockLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(
          3,
          (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: theme.dividerColor,
                              borderRadius: BorderRadius.circular(12))),
                      const SizedBox(width: 16),
                      const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ShimmerBlock(width: 100, height: 14),
                            SizedBox(height: 8),
                            _ShimmerBlock(width: 60, height: 10),
                          ])
                    ],
                  ),
                ),
              )),
    );
  }
}

class _HeiApiResult {
  final double score;
  final Map<String, double> macroSplit;
  final String dataSourceLabel;

  const _HeiApiResult({
    required this.score,
    required this.macroSplit,
    required this.dataSourceLabel,
  });
}

class _ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final bool isDark;
  const _ShimmerBlock(
      {required this.width, required this.height, this.isDark = false});
  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _controller,
        builder: (ctx, child) {
          final baseColor = widget.isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey[200]!;
          final highlightColor = widget.isDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.grey[100]!;
          return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                  color:
                      Color.lerp(baseColor, highlightColor, _controller.value),
                  borderRadius: BorderRadius.circular(4)));
        });
  }
}

class _DietCompositionCard extends StatelessWidget {
  final Map<String, int> data;
  const _DietCompositionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = data.values.fold(0, (sum, v) => sum + v);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Color getColor(String key) {
      switch (key) {
        case 'Veggies':
          return _reportMint;
        case 'Protein':
          return _reportPeach;
        case 'Dairy':
          return _reportLavender;
        case 'Fruits':
          return const Color(0xFFFFD6A5);
        default:
          return _reportSoftRed;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _reportPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: sorted
                        .map((e) => PieChartSectionData(
                              color: getColor(e.key),
                              value: e.value.toDouble(),
                              title: '',
                              radius: 16,
                            ))
                        .toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurface.withValues(alpha: 0.5)),
                    ),
                    Text(
                      total.toString(),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface),
                    ),
                    Text(
                      'Items',
                      style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sorted.map((e) {
                final pct = total == 0 ? 0 : (e.value / total * 100).round();
                final color = getColor(e.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(
                            e.key,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestockCard extends StatelessWidget {
  final String name;
  final String reason;
  final VoidCallback onAdd;
  const _RestockCard(
      {required this.name, required this.reason, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _reportPrimary.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _reportPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined, color: _reportPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: colors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, color: _reportPrimary),
          ),
        ],
      ),
    );
  }
}
