// lib/screens/impact_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../repositories/inventory_repository.dart';
import '../widgets/profile_avatar_button.dart'; // 确保路径正确

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

  static const Color _backgroundColor = Color(0xFFF8F9FC);
  static const Color _moneyColor = Color(0xFF005F87); 
  static const Color _co2Color = Color(0xFF43A047);

  void _changeRange(ImpactRange r) {
    HapticFeedback.selectionClick();
    setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repo,
      builder: (context, child) {
        final start = _rangeStart();
        
        // 筛选时间范围内的事件
        final events = widget.repo.impactEvents
            .where((e) => !e.date.isBefore(start))
            .toList();

        // 核心数据计算
        final streak = widget.repo.getCurrentStreakDays();
        final moneyTotal = events.fold<double>(0, (sum, e) => sum + e.moneySaved);
        final co2Total = events.fold<double>(0, (sum, e) => sum + e.co2Saved);
        final savedCount = events.length;

        // 宠物数据 (锁定为荷兰猪)
        final petEvents = events.where((e) => e.type == ImpactType.fedToPet).toList();
        final petQty = petEvents.fold<double>(0, (sum, e) => sum + e.quantity);
        final totalQty = events.fold<double>(0, (sum, e) => sum + e.quantity);
        final petShare = totalQty == 0 ? 0.0 : (petQty / totalQty).clamp(0.0, 1.0);

        // 🟢 图表数据准备 (同时准备 Money 和 CO2)
        final dailyMoney = <DateTime, double>{};
        final dailyCo2 = <DateTime, double>{};

        for (final e in events) {
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          dailyMoney[d] = (dailyMoney[d] ?? 0) + e.moneySaved;
          dailyCo2[d] = (dailyCo2[d] ?? 0) + e.co2Saved;
        }

        final allDates = {...dailyMoney.keys, ...dailyCo2.keys}.toList()..sort();
        
        final moneySpots = <FlSpot>[];
        final co2Spots = <FlSpot>[];
        final labels = <int, String>{};

        for (var i = 0; i < allDates.length; i++) {
          final d = allDates[i];
          final x = i.toDouble();
          moneySpots.add(FlSpot(x, dailyMoney[d] ?? 0));
          co2Spots.add(FlSpot(x, dailyCo2[d] ?? 0));
          labels[i] = _shortDate(d);
        }

        final bool hasEnoughData = moneySpots.length > 1;

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            title: const Text(
              'Impact Dashboard',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            backgroundColor: _backgroundColor,
            elevation: 0,
            centerTitle: false,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            actions: [
              ProfileAvatarButton(repo: widget.repo),
              const SizedBox(width: 16),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // 0. 时间筛选
              FadeInSlide(
                index: 0,
                child: _SlidingRangeSelector(
                  currentRange: _range,
                  onChanged: _changeRange,
                ),
              ),
              const SizedBox(height: 24),

              // 1. Money Hero (核心资产卡片)
              FadeInSlide(
                index: 1,
                child: _MoneyHeroCard(moneySaved: moneyTotal, savedCount: savedCount),
              ),
              
              const SizedBox(height: 16),

              // 2. Bento Grid (次级数据)
              FadeInSlide(
                index: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        title: 'CO₂ Reduced',
                        value: '${co2Total.toStringAsFixed(1)} kg',
                        icon: Icons.cloud_off_rounded,
                        color: _co2Color,
                        bgColor: _co2Color.withOpacity(0.1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        title: 'Day Streak',
                        value: '$streak',
                        icon: Icons.local_fire_department_rounded,
                        color: Colors.orange,
                        bgColor: Colors.orange.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. 荷兰猪专属卡片
              FadeInSlide(
                index: 3,
                child: _GuineaPigCard(
                  petQty: petQty,
                  petShare: petShare,
                ),
              ),

              const SizedBox(height: 32),

              // 4. 数据可视化：趋势图 (Money + CO2)
              if (hasEnoughData) ...[
                // Money Chart
                FadeInSlide(
                  index: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Savings Trend',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                FadeInSlide(
                  index: 5,
                  child: _ChartCard(
                    spots: moneySpots,
                    labels: labels,
                    color: _moneyColor,
                    unit: '€',
                  ),
                ),
                
                const SizedBox(height: 24),

                // 🟢 CO2 Chart (新增)
                FadeInSlide(
                  index: 6,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'CO₂ Reduction Trend',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                FadeInSlide(
                  index: 7,
                  child: _ChartCard(
                    spots: co2Spots,
                    labels: labels,
                    color: _co2Color,
                    unit: 'kg',
                  ),
                ),

              ] else if (events.isEmpty) ...[
                 FadeInSlide(index: 4, child: _EmptyStateCard()),
              ],

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

// ===================== UI Components =====================

// 1. Money Hero Card
class _MoneyHeroCard extends StatelessWidget {
  final double moneySaved;
  final int savedCount;

  const _MoneyHeroCard({required this.moneySaved, required this.savedCount});

  @override
  Widget build(BuildContext context) {
    final coffees = (moneySaved / 3.0).floor();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D70), Color(0xFF0083B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF005F87).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wallet, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'SAVINGS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.monetization_on_outlined, color: Colors.white.withOpacity(0.2), size: 24),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '€${moneySaved.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 20),
          
          Container(height: 1, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$savedCount Items',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Prevented from waste',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
              const SizedBox(width: 16),
               Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '≈ $coffees Coffees',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Value equivalent',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 2. Stat Box
class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// 3. Guinea Pig Card
class _GuineaPigCard extends StatelessWidget {
  final double petQty;
  final double petShare;
  const _GuineaPigCard({required this.petQty, required this.petShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // 暖黄色
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🐹', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Little Shi & Little Yuan', 
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    Text(
                      'Total Snacks: ${petQty.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5D4037).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 增加进度条可视化
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Diet Share',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown[300]),
                  ),
                  Text(
                    '${(petShare * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown[700]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: petShare,
                  backgroundColor: Colors.brown.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.brown[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Did you know? Guinea pigs "popcorn" (jump in the air) when they are excited about veggies!',
                    style: TextStyle(fontSize: 11, color: Colors.brown[600], fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// 4. Chart Card (趋势图)
class _ChartCard extends StatelessWidget {
  final List<FlSpot> spots;
  final Map<int, String> labels;
  final Color color;
  final String unit; // 🟢 新增单位参数

  const _ChartCard({
    required this.spots,
    required this.labels,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final double maxY = spots.isEmpty ? 5.0 : spots.fold(0.0, (m, s) => s.y > m ? s.y : m) * 1.2;
    final safeMaxY = maxY <= 0 ? 5.0 : maxY;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: safeMaxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100], strokeWidth: 1, dashArray: [5, 5]),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx == 0 || idx == labels.length - 1 || (labels.length > 4 && idx == labels.length ~/ 2)) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(labels[idx] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500)),
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
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
                ),
              ),
            ),
          ],
          // 🟢 悬浮提示增加单位
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} $unit',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 10,
            ),
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
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.03))),
      child: Column(children: [Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey[300]), const SizedBox(height: 16), Text("No data yet", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800])), const SizedBox(height: 8), Text("Start using items to see your impact!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], height: 1.5, fontSize: 13))]),
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
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = width / 3;
          return Stack(
            children: [
              AnimatedAlign(
                alignment: _getAlign(currentRange),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Container(
                  width: itemWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF005F87),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF005F87).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
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
                            color: isSelected ? Colors.white : Colors.grey[500],
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

  const FadeInSlide({super.key, required this.child, required this.index, this.duration = const Duration(milliseconds: 500)});

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
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(curve);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
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