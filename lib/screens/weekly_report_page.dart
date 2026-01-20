import 'dart:convert';
import 'package:flutter/foundation.dart'; // setEquals
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/inventory_repository.dart';
import '../models/food_item.dart';

// 馃煝 鍗囩骇鍚庣殑鏁版嵁妯″瀷
class WeeklyData {
  final double moneySaved;
  final double moneyWasted; // 鏂板锛氭氮璐归噾棰?
  final double co2;
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
      // 鍏煎鏃х増鏈紦瀛橈細濡傛灉娌℃湁 wasted 瀛楁锛岄粯璁や负 0
      moneyWasted: (json['moneyWasted'] as num?)?.toDouble() ?? 0.0, 
      co2: (json['co2'] as num).toDouble(),
      uniqueItems: (json['uniqueItems'] as List).map((e) => e.toString()).toSet(),
      categories: Map<String, int>.from(json['categories'] ?? {}),
      topItems: Map<String, int>.from(json['topItems'] ?? {}),
      aiInsight: json['aiInsight'],
      aiSuggestions: (json['aiSuggestions'] as List?)?.map((e) => Map<String, String>.from(e)).toList(),
      analyzedItemsSnapshot: (json['analyzedItemsSnapshot'] as List?)?.map((e) => e.toString()).toSet() ?? {},
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
  String _thisWeekPreset = '';
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

  // 馃煝 鏍稿績閫昏緫锛氬姞杞芥暟鎹?+ 缁熻娴垂 + 缁熻棰戠巼
  Future<void> _loadWeekData(int offset) async {
    final now = DateTime.now();
    // 璁＄畻鍛ㄧ殑璧锋鏃堕棿锛堝亣璁惧懆涓€鍒板懆鏃ワ紝鎴栫畝鍗曠殑7澶╂帹绠楋級
    final endDate = now.subtract(Duration(days: 7 * offset));
    final startDate = endDate.subtract(const Duration(days: 7));
    final nextWeekStart = endDate;
    final nextWeekEnd = endDate.add(const Duration(days: 7));

    // 鑾峰彇璇ユ椂闂存鍐呯殑鎵€鏈変簨浠?
    final events = widget.repo.impactEvents.where((e) {
      return e.date.isAfter(startDate) && e.date.isBefore(endDate);
    }).toList();

    double moneySaved = 0;
    double moneyWasted = 0;
    double co2 = 0;
    final currentUniqueItems = <String>{};
    final catCounts = <String, int>{};
    final itemFreq = <String, int>{}; // 棰戠巼缁熻
    final rawItemNamesForAi = <String>[];

    for (var e in events) {
      // 缁熻娑堣€?(Saved)
      if (e.type == ImpactType.eaten || e.type == ImpactType.fedToPet) {
        moneySaved += e.moneySaved;
        co2 += e.co2Saved;
        
        final name = e.itemName ?? 'Unknown Item';
        if (e.itemName != null && e.itemName!.isNotEmpty) {
          currentUniqueItems.add(name);
          rawItemNamesForAi.add(name);
          
          // 缁熻棰戠巼
          itemFreq[name] = (itemFreq[name] ?? 0) + 1;

          // 缁熻鍒嗙被
          final key = _inferCategory(e.itemCategory, name);
          catCounts[key] = (catCounts[key] ?? 0) + 1;
        }
      } 
      // 缁熻娴垂 (Waste)
      else if (e.type == ImpactType.trash) {
        // 鍋囪 ImpactEvent 涓?moneySaved 鍦?trash 绫诲瀷涓嬩唬琛ㄦ崯澶辩殑閲戦
        // 濡傛灉浣犵殑閫昏緫涓嶅悓锛岃繖閲岄渶瑕佽皟鏁达紝姣斿 e.cost
        moneyWasted += e.moneySaved; 
      }
    }

    // 瀵归鐜囪繘琛屾帓搴?
    final sortedTopItems = Map.fromEntries(
      itemFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
    );

    // 灏濊瘯鑾峰彇缂撳瓨
    WeeklyData? cachedData = _memoryCache[offset];
    if (cachedData == null) {
      cachedData = await _loadFromDisk(offset);
      if (cachedData != null) {
        _memoryCache[offset] = cachedData;
      }
    }

    // 鍒ゆ柇鏄惁鍙互浣跨敤缂撳瓨鐨?AI 鎶ュ憡
    final plannedMealsThisWeek = _buildPlannedMealsPayload(startDate, endDate);
    final plannedMealsNextWeek = _buildPlannedMealsPayload(nextWeekStart, nextWeekEnd);
    final plannedSnapshot = _buildPlannedMealsSnapshot(plannedMealsThisWeek, plannedMealsNextWeek);
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

    // 鏋勫缓鏂版暟鎹璞?
    final newData = WeeklyData(
      moneySaved: moneySaved,
      moneyWasted: moneyWasted,
      co2: co2,
      uniqueItems: currentUniqueItems,
      categories: catCounts,
      topItems: sortedTopItems,
      aiInsight: canUseCachedAi ? cachedData!.aiInsight : cachedData?.aiInsight,
      aiSuggestions: canUseCachedAi ? cachedData!.aiSuggestions : cachedData?.aiSuggestions,
      isAiLoading: !canUseCachedAi && currentUniqueItems.isNotEmpty,
      analyzedItemsSnapshot: canUseCachedAi ? cachedData!.analyzedItemsSnapshot : const {},
      contextSnapshot: contextSnapshot,
    );

    _memoryCache[offset] = newData;
    if (mounted) setState(() {});

    // 璇锋眰 AI
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
        moneySaved: moneySaved, moneyWasted: moneyWasted, co2: co2, 
        uniqueItems: {}, categories: {}, topItems: {},
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
      final key = 'weekly_report_v2_$offset'; // 鍗囩骇 version key 浠ラ伩鍏嶈В鏋愭棫鏁版嵁閿欒
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
      final historyContext = _buildWeeklyComparisonContext(weekOffset: offset);
      final consumptionCounts = itemFreq.map((k, v) => MapEntry(k, v));
      final weekContext = _buildWeekContext();
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'analyze_diet',
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
              uniqueItems: currentBase.uniqueItems,
              categories: currentBase.categories,
              topItems: currentBase.topItems,
              aiInsight: data['insight'],
              aiSuggestions: list.map((e) => {
                'name': e['name']?.toString() ?? '',
                'category': e['category']?.toString() ?? 'general',
                'reason': e['reason']?.toString() ?? '',
              }).toList(),
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
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF005F87))),
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
    HapticFeedback.lightImpact();
    setState(() => _weekOffset = 0);
    _loadWeekData(0);
  }

  String _inferCategory(String? cat, String name) {
    final c = (cat ?? '').toLowerCase();
    final n = name.toLowerCase();
    if (c.contains('veg') || c.contains('salad') || n.contains('onion') || n.contains('carrot') || n.contains('spinach')) return 'Veggies';
    if (c.contains('fruit') || n.contains('banana') || n.contains('apple') || n.contains('berry')) return 'Fruits';
    if (c.contains('meat') || c.contains('fish') || c.contains('egg') || n.contains('beef') || n.contains('chicken')) return 'Protein';
    if (c.contains('dairy') || c.contains('cheese') || c.contains('milk')) return 'Dairy';
    if (c.contains('carb') || c.contains('bread') || c.contains('rice') || c.contains('pasta')) return 'Carbs';
    return 'Other';
  }

  Map<String, dynamic> _buildWeeklyComparisonContext({required int weekOffset}) {
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
      'topItems': topItems.take(8).map((e) => {'name': e.key, 'count': e.value}).toList(),
      'categoryMix': categoryCounts,
    };
  }
  
  String _getDateRangeString() {
    final now = DateTime.now();
    final end = now.subtract(Duration(days: 7 * _weekOffset));
    final start = end.subtract(const Duration(days: 7));
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }

  Future<void> _addToShoppingList(String name, String category) async {
    final newItem = ShoppingItem(
      id: const Uuid().v4(),
      name: name,
      category: category,
      isChecked: false,
    );
    await widget.repo.saveShoppingItem(newItem);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF005F87),
        content: Text('Added to shopping list.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _restockContextSnapshot() {
    return '${_thisWeekController.text.trim()}|${_nextWeekController.text.trim()}';
  }

  String _buildAiContextSnapshot(String plannedSnapshot) {
    return '${_restockContextSnapshot()}|planned:$plannedSnapshot';
  }

  List<Map<String, dynamic>> _buildPlannedMealsPayload(DateTime start, DateTime end) {
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
      return list
          .map((e) {
            final items = (e['itemIds'] as List? ?? []).join(',');
            return '${e['date']}|${e['slot']}|${e['recipeName'] ?? ''}|$items';
          })
          .join(';');
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF005F87) : theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? Colors.transparent : theme.dividerColor),
              ),
              child: Text(
                preset,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : colors.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us your week',
            style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
          ),
          const SizedBox(height: 12),
          Text(
            'This week I am...',
            style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _thisWeekController,
            decoration: InputDecoration(
              hintText: 'e.g. Working out',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) {
              if (_thisWeekPreset.isNotEmpty) {
                setState(() => _thisWeekPreset = '');
              }
            },
          ),
          const SizedBox(height: 10),
          buildPresetRow(
            selected: _thisWeekPreset,
            onSelected: (preset) {
              setState(() {
                _thisWeekPreset = preset;
                _thisWeekController.text = preset;
              });
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Next week I will...',
            style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nextWeekController,
            decoration: InputDecoration(
              hintText: 'e.g. Finals week',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) {
              if (_nextWeekPreset.isNotEmpty) {
                setState(() => _nextWeekPreset = '');
              }
            },
          ),
          const SizedBox(height: 10),
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _loadWeekData(_weekOffset),
              child: const Text('Update restock suggestions'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _memoryCache[_weekOffset] ?? WeeklyData(moneySaved: 0, co2: 0, uniqueItems: {}, categories: {});

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: colors.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Weekly Wrap-Up', style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface)),
        ),
      body: Column(
        children: [
          _WeekSelector(
            dateRange: _getDateRangeString(),
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

                  // 馃煝 鏂板锛氭晥鐜囪鍒嗗崱 (Saved vs Wasted)
                  _EfficiencyScorecard(
                    saved: data.moneySaved, 
                    wasted: data.moneyWasted, 
                    co2: data.co2
                  ),

                  const SizedBox(height: 24),

                  // Diet Mix Chart
                  if (data.categories.isNotEmpty) ...[
                    Text(
                      'Your Diet Mix',
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

                  // 馃煝 鏂板锛歍op Items (High Frequency)
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
                            color: colors.onSurface.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _TopItemsList(topItems: data.topItems, allItems: data.uniqueItems),
                    const SizedBox(height: 24),
                  ],

                  // Smart Restock
                  Row(
                    children: [
                      Icon(Icons.shopping_basket_outlined, size: 20, color: Colors.deepOrange.shade400),
                      const SizedBox(width: 8),
                      const Text('Smart Restock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildContextInputCard(context),
                  const SizedBox(height: 16),

                  if (data.isAiLoading)
                      const _RestockLoadingSkeleton()
                  else if (data.aiSuggestions == null || data.aiSuggestions!.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        'No suggestions needed. You are doing great!',
                        style: TextStyle(color: colors.onSurface.withOpacity(0.6)),
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
                          onAdd: () => _addToShoppingList(item['name']!, item['category']!),
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

class _EfficiencyScorecard extends StatelessWidget {
  final double saved;
  final double wasted;
  final double co2;

  const _EfficiencyScorecard({required this.saved, required this.wasted, required this.co2});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = saved + wasted;
    // 閬垮厤闄や互0
    final savedPct = total == 0 ? 0 : (saved / total * 100).toInt();
    final wastedPct = total == 0 ? 0 : (wasted / total * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inventory Efficiency',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (wasted == 0 && saved > 0) ? Colors.green.shade50 : ((wasted > saved) ? Colors.red.shade50 : Colors.blue.shade50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (total == 0) ? 'No Activity' : ((wasted == 0) ? 'Perfect!' : 'Analyze Waste'),
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.bold,
                    color: (wasted == 0 && saved > 0) ? Colors.green : ((wasted > saved) ? Colors.red : Colors.blue),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAVED',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'EUR ${saved.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF005F87)),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: colors.onSurface.withOpacity(0.1)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'WASTED',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '-EUR ${wasted.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 26, 
                        fontWeight: FontWeight.w800, 
                        color: wasted > 0 ? const Color(0xFFD32F2F) : colors.onSurface.withOpacity(0.3)
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Efficiency Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                if (saved > 0)
                  Expanded(flex: savedPct, child: Container(height: 8, color: const Color(0xFF005F87))),
                if (wasted > 0)
                  Expanded(flex: wastedPct, child: Container(height: 8, color: const Color(0xFFFFCDD2))),
                if (total == 0)
                   Expanded(child: Container(height: 8, color: colors.onSurface.withOpacity(0.1))),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.forest_rounded, size: 16, color: Colors.green.shade400),
              const SizedBox(width: 6),
              Text(
                '${co2.toStringAsFixed(1)}kg CO2 avoided',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
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
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: idx == 0 ? const Color(0xFFFFECB3) : (idx == 1 ? Colors.grey[200] : Colors.orange[50]),
                    shape: BoxShape.circle
                  ),
                  child: Text(
                    '#${idx + 1}', 
                    style: TextStyle(
                      color: idx == 0 ? Colors.orange[800] : Colors.grey[700], 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12
                    )
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  item.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colors.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.value}x',
                    style: TextStyle(
                      color: colors.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF005F87))
            ),
            children: [
               Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allItems.skip(3).map((name) => Chip(
                     label: Text(name),
                     backgroundColor: theme.cardColor,
                     side: BorderSide(color: theme.dividerColor),
                     labelStyle: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.7)),
                  )).toList(),
               ),
               const SizedBox(height: 16),
            ],
          ),
      ],
    );
  }
}

class _WeekSelector extends StatelessWidget {
  final String dateRange;
  final int offset;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapDate;
  final VoidCallback onReset;

  const _WeekSelector({    required this.dateRange,    required this.offset,    required this.onPrev,    required this.onNext,    required this.onTapDate,    required this.onReset,  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            color: colors.onSurface,
            tooltip: 'Previous Week',
          ),
          
          Expanded(
            child: InkWell(
              onTap: onTapDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          offset == 0 ? 'This Week' : (offset == 1 ? 'Last Week' : '$offset Weeks Ago'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.onSurface),
                        ),
                        const SizedBox(width: 4),
                        if (offset != 0)
                          GestureDetector(
                            onTap: onReset,
                            child: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF005F87)),
                          )
                        else
                          Icon(Icons.calendar_today_rounded, size: 12, color: colors.onSurface.withOpacity(0.4)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateRange,
                      style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          IconButton(
            onPressed: offset == 0 ? null : onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            color: offset == 0 ? colors.onSurface.withOpacity(0.3) : colors.onSurface,
            tooltip: 'Next Week',
          ),
        ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // BSH Style Gradient
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002E4D), Color(0xFF005F87)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF002E4D).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF4DD0E1), size: 28),
          ),
          const SizedBox(height: 16),
          if (isLoading) ...[
              const _ShimmerBlock(width: 200, height: 16, isDark: true),
              const SizedBox(height: 8),
              const _ShimmerBlock(width: 150, height: 16, isDark: true),
          ] else
            Text(
              '"${insight ?? 'Analysis failed. Check your connection.'}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isLoading ? 'ANALYZING...' : 'AI DIET ANALYSIS',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB2EBF2), letterSpacing: 1),
            ),
          ),
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
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 16),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
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

class _ShimmerBlock extends StatefulWidget { 
  final double width; final double height; final bool isDark;
  const _ShimmerBlock({required this.width, required this.height, this.isDark = false}); 
  @override State<_ShimmerBlock> createState() => _ShimmerBlockState(); 
}
class _ShimmerBlockState extends State<_ShimmerBlock> with SingleTickerProviderStateMixin { 
  late AnimationController _controller; 
  @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { 
    return AnimatedBuilder(animation: _controller, builder: (ctx, child) {
      final baseColor = widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!;
      final highlightColor = widget.isDark ? Colors.white.withOpacity(0.3) : Colors.grey[100]!;
      return Container(width: widget.width, height: widget.height, decoration: BoxDecoration(color: Color.lerp(baseColor, highlightColor, _controller.value), borderRadius: BorderRadius.circular(4)));
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
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    Color getColor(String key) {
      switch(key) {
        case 'Veggies': return const Color(0xFF4CAF50);
        case 'Fruits': return const Color(0xFFFF9800);
        case 'Protein': return const Color(0xFFF44336);
        case 'Dairy': return const Color(0xFF2196F3);
        case 'Carbs': return const Color(0xFFFFC107);
        case 'Snacks': return const Color(0xFF9C27B0);
        case 'Drinks': return const Color(0xFF00BCD4);
        default: return Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100, height: 100,
            child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 30, sections: sorted.map((e) => PieChartSectionData(color: getColor(e.key), value: e.value.toDouble(), title: '', radius: 12)).toList())),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: sorted.map((e) {
                final pct = (e.value / total * 100).toStringAsFixed(0);
                final color = getColor(e.key);
                return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(e.key, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colors.onSurface))), Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.onSurface.withOpacity(0.6)))]));
              }).toList()),
          )
        ],
      ),
    );
  }
}

class _RestockCard extends StatelessWidget {
  final String name;
  final String reason;
  final VoidCallback onAdd;
  const _RestockCard({required this.name, required this.reason, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFBE9E7), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.add_shopping_cart_rounded, color: Colors.deepOrange.shade400, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: colors.onSurface)), const SizedBox(height: 2), Text(reason, style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: 12))])),
          IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.deepOrange))
        ]),
    );
  }
}






















