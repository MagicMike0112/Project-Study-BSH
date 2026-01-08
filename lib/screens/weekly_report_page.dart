// lib/screens/weekly_report_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // 建议引入 intl 包格式化日期，这里我手写简单格式化以减少依赖

import '../repositories/inventory_repository.dart';
import '../models/food_item.dart';

// 🟢 数据缓存模型：把每一周的数据存起来
class WeeklyData {
  final double money;
  final double co2;
  final Set<String> uniqueItems;
  final Map<String, int> categories;
  
  // AI 部分（可能为空，表示还在加载）
  String? aiInsight;
  List<Map<String, String>>? aiSuggestions;
  bool isAiLoading;

  WeeklyData({
    required this.money,
    required this.co2,
    required this.uniqueItems,
    required this.categories,
    this.aiInsight,
    this.aiSuggestions,
    this.isAiLoading = true,
  });
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
  // 🟢 缓存：Key是周偏移量(0, 1, 2...)，Value是该周的数据
  final Map<int, WeeklyData> _cache = {};
  
  int _weekOffset = 0; // 0 = 本周

  @override
  void initState() {
    super.initState();
    _loadWeekData(_weekOffset);
  }

  // 🟢 核心逻辑：加载数据（本地计算立即完成，AI异步加载）
  Future<void> _loadWeekData(int offset) async {
    // 1. 如果缓存里已经有完整的 AI 数据，直接用缓存，不需要任何加载状态
    if (_cache.containsKey(offset) && _cache[offset]!.isAiLoading == false) {
      setState(() {}); 
      return;
    }

    // 2. 计算时间窗口
    final now = DateTime.now();
    // 这里的逻辑：offset=0 是 "本周" (从今天往前推7天，或者按自然周算，这里按过去7天滚动窗口)
    final endDate = now.subtract(Duration(days: 7 * offset));
    final startDate = endDate.subtract(const Duration(days: 7));

    // 3. 本地统计 (同步计算，瞬间完成)
    final events = widget.repo.impactEvents.where((e) {
      return e.date.isAfter(startDate) && 
             e.date.isBefore(endDate) && 
             e.type == ImpactType.eaten; 
    }).toList();

    double money = 0;
    double co2 = 0;
    final uniqueNames = <String>{};
    final catCounts = <String, int>{};
    final rawItemNamesForAi = <String>[];

    for (var e in events) {
      money += e.moneySaved;
      co2 += e.co2Saved;
      
      final name = e.itemName ?? 'Unknown Item';
      if (e.itemName != null && e.itemName!.isNotEmpty) {
        uniqueNames.add(name);
        rawItemNamesForAi.add(name);
      }

      final key = _inferCategory(e.itemCategory, name);
      catCounts[key] = (catCounts[key] ?? 0) + 1;
    }

    // 4. 更新缓存（先存本地数据，标记 AI 为 loading）
    // 如果之前有缓存且 AI 已加载，保留 AI 数据；否则新建
    if (!_cache.containsKey(offset)) {
        _cache[offset] = WeeklyData(
          money: money,
          co2: co2,
          uniqueItems: uniqueNames,
          categories: catCounts,
          isAiLoading: true, // 标记 AI 需要加载
        );
    }
    
    // 立即刷新 UI，用户马上能看到统计数据，不用转圈
    setState(() {});

    // 5. 异步加载 AI (如果需要)
    // 只有当有食物记录，且AI数据还没加载时才请求
    if (uniqueNames.isNotEmpty && (_cache[offset]?.aiInsight == null)) {
      await _fetchAiInsight(offset, rawItemNamesForAi);
    } else if (uniqueNames.isEmpty) {
      // 没吃东西，直接给默认文案
      _cache[offset]?.aiInsight = "No meals logged this week. Time to cook!";
      _cache[offset]?.aiSuggestions = [];
      _cache[offset]?.isAiLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchAiInsight(int offset, List<String> items) async {
    try {
      final uri = Uri.parse('https://project-study-bsh.vercel.app/api/recipe');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'analyze_diet',
          'consumed': items,
          'studentMode': widget.studentMode,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = data['suggestions'] as List? ?? [];
        
        if (mounted) {
          setState(() {
            _cache[offset]?.aiInsight = data['insight'];
            _cache[offset]?.aiSuggestions = list.map((e) => {
              'name': e['name']?.toString() ?? '',
              'category': e['category']?.toString() ?? 'general',
              'reason': e['reason']?.toString() ?? '',
            }).toList();
            _cache[offset]?.isAiLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cache[offset]?.aiInsight = "AI is currently unavailable.";
          _cache[offset]?.isAiLoading = false;
        });
      }
    }
  }

  // 🟢 日历选择逻辑
  Future<void> _pickDate() async {
    final now = DateTime.now();
    // 允许选过去1年的日期
    final firstDate = now.subtract(const Duration(days: 365));
    
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(Duration(days: 7 * _weekOffset)),
      firstDate: firstDate,
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF005F87)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // 计算选中的日期距离现在有多少周
      final diff = now.difference(picked).inDays;
      // 这里的逻辑：offset = 天数差 / 7
      // 比如今天选今天，diff=0, offset=0
      // 选7天前，diff=7, offset=1
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
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF005F87),
        content: Text('Added "$name" to list ✅'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前周的数据，如果还没生成，先用空数据占位
    final data = _cache[_weekOffset] ?? WeeklyData(money: 0, co2: 0, uniqueItems: {}, categories: {});

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FC),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Weekly Wrap-Up', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)),
      ),
      body: Column(
        children: [
          // 🟢 1. 增强版周次选择器 (带日历功能)
          _WeekSelector(
            dateRange: _getDateRangeString(),
            offset: _weekOffset,
            onPrev: () => _changeWeek(1),
            onNext: () => _changeWeek(-1),
            onTapDate: _pickDate, // 🟢 点击日期触发日历
          ),

          // 2. 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🟢 AI Insight 卡片 (支持 Loading 状态)
                  _InsightHeroCard(
                    insight: data.aiInsight,
                    isLoading: data.isAiLoading,
                  ),
                  
                  const SizedBox(height: 24),

                  // Stats Grid (使用本地缓存数据，瞬间显示)
                  Row(
                    children: [
                      Expanded(child: _MiniStatCard(label: 'Money Saved', value: '€${data.money.toStringAsFixed(0)}', icon: Icons.savings_outlined, color: Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _MiniStatCard(label: 'CO₂ Avoided', value: '${data.co2.toStringAsFixed(1)}kg', icon: Icons.cloud_outlined, color: Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(child: _MiniStatCard(label: 'Varieties', value: '${data.uniqueItems.length}', icon: Icons.restaurant_menu, color: Colors.orange)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (data.categories.isNotEmpty) ...[
                    const Text('Your Diet Mix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _DietCompositionCard(data: data.categories),
                    const SizedBox(height: 24),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('On Your Plate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${data.uniqueItems.length} Unique Items', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (data.uniqueItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: const Text('Nothing logged for this week.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.uniqueItems.map((name) => Chip(
                        label: Text(name),
                        backgroundColor: Colors.white,
                        elevation: 0,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      )).toList(),
                    ),

                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Icon(Icons.shopping_basket_outlined, size: 20, color: Colors.deepOrange.shade400),
                      const SizedBox(width: 8),
                      const Text('Smart Restock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 🟢 建议列表 (支持 Loading 状态)
                  if (data.isAiLoading)
                     const _RestockLoadingSkeleton()
                  else if (data.aiSuggestions == null || data.aiSuggestions!.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: const Text('No suggestions needed. You are doing great!', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
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

class _WeekSelector extends StatelessWidget {
  final String dateRange;
  final int offset;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapDate; // 🟢 新增回调

  const _WeekSelector({
    required this.dateRange,
    required this.offset,
    required this.onPrev,
    required this.onNext,
    required this.onTapDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.black87,
            tooltip: 'Previous Week',
          ),
          // 🟢 可点击区域
          InkWell(
            onTap: onTapDate,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        offset == 0 ? 'This Week' : (offset == 1 ? 'Last Week' : '$offset Weeks Ago'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade600), // 🟢 日历图标
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateRange,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: offset == 0 ? null : onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            color: offset == 0 ? Colors.grey.shade200 : Colors.black87,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF005F87).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF005F87), size: 32),
          ),
          const SizedBox(height: 16),
          // 🟢 支持 Loading 态
          if (isLoading) ...[
             const _ShimmerBlock(width: 200, height: 16),
             const SizedBox(height: 8),
             const _ShimmerBlock(width: 150, height: 16),
          ] else
            Text(
              '"${insight ?? '...'}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D3436),
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isLoading ? 'ANALYZING...' : 'AI DIET ANALYSIS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1),
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
    return Column(
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12))),
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
  final double width; final double height; 
  const _ShimmerBlock({required this.width, required this.height}); 
  @override State<_ShimmerBlock> createState() => _ShimmerBlockState(); 
}
class _ShimmerBlockState extends State<_ShimmerBlock> with SingleTickerProviderStateMixin { 
  late AnimationController _controller; 
  @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { 
    return AnimatedBuilder(animation: _controller, builder: (ctx, child) {
      return Container(width: widget.width, height: widget.height, decoration: BoxDecoration(color: Color.lerp(Colors.grey[200], Colors.grey[100], _controller.value), borderRadius: BorderRadius.circular(4)));
    });
  } 
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniStatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DietCompositionCard extends StatelessWidget {
  final Map<String, int> data;
  const _DietCompositionCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0, (sum, v) => sum + v);
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    Color getColor(String key) {
      switch(key) {
        case 'Veggies': return Colors.green;
        case 'Fruits': return Colors.orange;
        case 'Protein': return Colors.redAccent;
        case 'Dairy': return Colors.blueAccent;
        case 'Carbs': return Colors.amber;
        case 'Snacks': return Colors.purpleAccent;
        case 'Drinks': return Colors.cyan;
        default: return Colors.grey;
      }
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
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
                return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))]));
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFBE9E7), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.add_shopping_cart_rounded, color: Colors.deepOrange.shade400, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 2), Text(reason, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
          IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.deepOrange))
        ]),
    );
  }
}