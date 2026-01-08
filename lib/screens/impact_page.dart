// lib/screens/impact_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../models/food_item.dart'; 
import '../repositories/inventory_repository.dart';
import '../utils/impact_helpers.dart'; 
import '../widgets/profile_avatar_button.dart'; 
import 'weekly_report_page.dart'; 

enum ImpactRange { week, month, year }

class ImpactPage extends StatefulWidget {
  final InventoryRepository repo;
  const ImpactPage({super.key, required this.repo});

  @override
  State<ImpactPage> createState() => _ImpactPageState();
}

class _ImpactPageState extends State<ImpactPage> {
  ImpactRange _range = ImpactRange.week;

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

  String _shortDate(DateTime d) => '${d.month}/${d.day}';

  static const Color _backgroundColor = Color(0xFFF4F6F9);
  static const Color _moneyColor = Color(0xFF2D3436); 
  static const Color _accentColor = Color(0xFF005F87);

  void _changeRange(ImpactRange r) {
    HapticFeedback.lightImpact();
    setState(() => _range = r);
  }

  // 🟢 核心修复：智能分类推断逻辑
  // 即使数据库里存的是 "manual"，也能根据名字修修正为 "Veggies" 等
  String _inferCategory(String? cat, String? name) {
    final c = (cat ?? '').toLowerCase();
    final n = (name ?? '').toLowerCase();

    // 1. 优先匹配 Category 关键词 (如果 Category 比较明确)
    if (c.contains('veg') || c.contains('salad')) return 'Veggies';
    if (c.contains('fruit') || c.contains('berry')) return 'Fruits';
    if (c.contains('meat') || c.contains('beef') || c.contains('pork') || c.contains('chicken') || c.contains('fish')) return 'Protein';
    if (c.contains('dairy') || c.contains('cheese') || c.contains('milk') || c.contains('yogurt')) return 'Dairy';
    if (c.contains('bread') || c.contains('rice') || c.contains('pasta') || c.contains('noodle') || c.contains('cereal')) return 'Carbs';
    if (c.contains('snack') || c.contains('chip') || c.contains('chocolate')) return 'Snacks';
    if (c.contains('drink') || c.contains('beverage') || c.contains('juice') || c.contains('coffee') || c.contains('tea')) return 'Drinks';

    // 2. 如果 Category 没匹配到 (比如是 manual/other)，尝试匹配 Name 关键词 (补救措施)
    // Veggies
    if (n.contains('onion') || n.contains('carrot') || n.contains('potato') || n.contains('tomato') || n.contains('spinach') || n.contains('lettuce') || n.contains('cucumber') || n.contains('pepper') || n.contains('broccoli')) return 'Veggies';
    // Fruits
    if (n.contains('banana') || n.contains('apple') || n.contains('orange') || n.contains('grape') || n.contains('berry') || n.contains('lemon')) return 'Fruits';
    // Protein
    if (n.contains('egg') || n.contains('tofu') || n.contains('bean') || n.contains('sausage') || n.contains('ham')) return 'Protein';
    // Carbs
    if (n.contains('rice') || n.contains('bread') || n.contains('toast') || n.contains('bagel') || n.contains('pizza')) return 'Carbs';
    // Dairy
    if (n.contains('milk') || n.contains('butter') || n.contains('cream')) return 'Dairy';
    // Drinks
    if (n.contains('water') || n.contains('coke') || n.contains('soda') || n.contains('beer') || n.contains('wine')) return 'Drinks';

    // 3. 兜底
    if (c == 'manual' || c.isEmpty) return 'General';
    return c; // 返回原始值作为最后的保底 (如 'Pantry')
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repo,
      builder: (context, child) {
        final start = _rangeStart();
        
        final events = widget.repo.impactEvents
            .where((e) => !e.date.isBefore(start))
            .toList();

        // 核心数据计算
        final streak = widget.repo.getCurrentStreakDays();
        final moneyTotal = events.fold<double>(0, (sum, e) => sum + e.moneySaved);
        final co2Total = events.fold<double>(0, (sum, e) => sum + e.co2Saved);
        final savedCount = events.length;

        // --- 🟢 Top Savers (修复版) ---
        final categoryMap = <String, double>{};
        for (var e in events) {
          if (e.type == ImpactType.eaten) {
            // 使用智能分类器清洗数据，消除 "MANUAL"
            final cat = _inferCategory(e.itemCategory, e.itemName);
            categoryMap[cat] = (categoryMap[cat] ?? 0) + e.moneySaved;
          }
        }
        final sortedCategories = categoryMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topCategories = sortedCategories.take(3).toList();

        // 宠物数据
        final petEvents = events.where((e) => e.type == ImpactType.fedToPet).toList();
        final petQty = petEvents.fold<double>(0, (sum, e) => sum + e.quantity);
        final totalQty = events.fold<double>(0, (sum, e) => sum + e.quantity);
        final petShare = totalQty == 0 ? 0.0 : (petQty / totalQty).clamp(0.0, 1.0);

        // 图表数据
        final dailyMoney = <DateTime, double>{};
        for (final e in events) {
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          dailyMoney[d] = (dailyMoney[d] ?? 0) + e.moneySaved;
        }

        final allDates = dailyMoney.keys.toList()..sort();
        final moneySpots = <FlSpot>[];
        final labels = <int, String>{};

        for (var i = 0; i < allDates.length; i++) {
          final d = allDates[i];
          final x = i.toDouble();
          moneySpots.add(FlSpot(x, dailyMoney[d] ?? 0));
          labels[i] = _shortDate(d);
        }

        final bool hasEnoughData = moneySpots.isNotEmpty;

        return Scaffold(
          backgroundColor: _backgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 100.0,
                floating: false,
                pinned: true,
                backgroundColor: _backgroundColor,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: const Text(
                    'Your Impact',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                ),
                actions: [
                  Center(child: ProfileAvatarButton(repo: widget.repo)),
                  const SizedBox(width: 20),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      FadeInSlide(
                        index: 0,
                        child: _WeeklyReportBanner(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WeeklyReportPage(repo: widget.repo),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      FadeInSlide(
                        index: 1,
                        child: _SlidingRangeSelector(
                          currentRange: _range,
                          onChanged: _changeRange,
                        ),
                      ),
                      const SizedBox(height: 20),

                      FadeInSlide(
                        index: 2,
                        child: _ImpactHeroCard(
                          moneySaved: moneyTotal,
                          savedCount: savedCount,
                          rangeMode: _range.name, 
                        ),
                      ),
                      const SizedBox(height: 16),

                      FadeInSlide(
                        index: 3,
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatBentoCard(
                                title: 'CO₂ Avoided',
                                value: '${co2Total.toStringAsFixed(1)} kg',
                                subtitle: ImpactHelpers.getCo2Equivalent(co2Total), 
                                icon: Icons.forest_rounded,
                                color: const Color(0xFF43A047),
                                bgColor: const Color(0xFFE8F5E9),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatBentoCard(
                                title: 'Streak',
                                value: '$streak Days',
                                subtitle: 'Keep it up!',
                                icon: Icons.local_fire_department_rounded,
                                color: Colors.deepOrange,
                                bgColor: Colors.deepOrange.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // 🟢 Top Savers (分类榜单 - 现已智能修复)
                      if (topCategories.isNotEmpty) ...[
                        FadeInSlide(
                          index: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top Savers',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _CategoryBreakdownCard(categories: topCategories),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      FadeInSlide(
                        index: 5,
                        child: _GuineaPigCard(
                          petQty: petQty,
                          petShare: petShare,
                        ),
                      ),

                      const SizedBox(height: 32),

                      if (hasEnoughData) ...[
                        FadeInSlide(
                          index: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Savings Trend',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ChartCard(
                                spots: moneySpots,
                                labels: labels,
                                color: _accentColor,
                                unit: '€',
                              ),
                            ],
                          ),
                        ),
                      ] else if (events.isEmpty) ...[
                        FadeInSlide(index: 6, child: _EmptyStateCard()),
                      ],

                      const SizedBox(height: 100), 
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================== UI Components =====================

class _WeeklyReportBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _WeeklyReportBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.withOpacity(0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Recap Ready',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
                  Text(
                    'Tap to view your diet insights',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
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
    final equivalent = ImpactHelpers.getMoneyEquivalent(moneySaved);
    final projection = ImpactHelpers.getProjectedSavings(moneySaved, rangeMode);
    final title = ImpactHelpers.getSavingsTitle(moneySaved);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C5364).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
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
              Icon(Icons.stars_rounded, color: Colors.amber.shade300, size: 28),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('€', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
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
            style: TextStyle(color: Colors.greenAccent.shade100, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        'Based on $savedCount items saved',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    cat.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  '+€${amount.toStringAsFixed(2)}',
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
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
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuineaPigCard extends StatelessWidget {
  final double petQty;
  final double petShare;
  const _GuineaPigCard({required this.petQty, required this.petShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.1), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: Text('🐹', style: TextStyle(fontSize: 30))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Little Shi & Yuan',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF5D4037)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enjoyed ${petQty.toStringAsFixed(1)}kg of leftovers',
                  style: TextStyle(fontSize: 13, color: const Color(0xFF5D4037).withOpacity(0.7)),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: petShare,
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                    minHeight: 6,
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
    final double maxY = spots.isEmpty ? 5.0 : spots.fold(0.0, (m, s) => s.y > m ? s.y : m) * 1.2;
    final safeMaxY = maxY <= 0 ? 5.0 : maxY;

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(0, 24, 24, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: safeMaxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[100], 
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
                  if (idx == 0 || idx == labels.length - 1 || (labels.length > 4 && idx == labels.length ~/ 2)) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        labels[idx] ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.bold),
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
                  colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
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
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No data yet",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Start saving food to see your impact!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = width / 3;
          return Stack(
            children: [
              AnimatedAlign(
                alignment: _getAlign(currentRange),
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                child: Container(
                  width: itemWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              Row(
                children: ImpactRange.values.map((r) {
                  final isSelected = r == currentRange;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => onChanged(r),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.black87 : Colors.grey[600],
                          ),
                          child: Text(_label(r)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Alignment _getAlign(ImpactRange r) {
    switch(r) {
      case ImpactRange.week: return Alignment.centerLeft;
      case ImpactRange.month: return Alignment.center;
      case ImpactRange.year: return Alignment.centerRight;
    }
  }

  String _label(ImpactRange r) {
    switch(r) {
      case ImpactRange.week: return '7 Days';
      case ImpactRange.month: return '30 Days';
      case ImpactRange.year: return '1 Year';
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