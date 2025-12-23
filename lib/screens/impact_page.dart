// lib/screens/impact_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../repositories/inventory_repository.dart';

enum ImpactRange { week, month, year }

class ImpactPage extends StatefulWidget {
  final InventoryRepository repo;
  const ImpactPage({super.key, required this.repo});

  @override
  State<ImpactPage> createState() => _ImpactPageState();
}

class _ImpactPageState extends State<ImpactPage> {
  ImpactRange _range = ImpactRange.week;

  // --- 保持原有逻辑不变 ---
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

  String _rangeLabel(ImpactRange r) {
    switch (r) {
      case ImpactRange.week:
        return '7 Days'; // 稍微调整大小写，看起来更工整
      case ImpactRange.month:
        return '30 Days';
      case ImpactRange.year:
        return '1 Year';
    }
  }

  String _shortDate(DateTime d) => '${d.month}/${d.day}';
  // --- 逻辑结束 ---

  // 统一的背景色
  static const Color _backgroundColor = Color(0xFFF8F9FC);

  @override
  Widget build(BuildContext context) {
    final start = _rangeStart();

    // 逻辑：数据过滤与聚合
    final events = widget.repo.impactEvents
        .where((e) => !e.date.isBefore(start))
        .toList();

    final streak = widget.repo.getCurrentStreakDays();

    final moneyTotal =
        events.fold<double>(0, (sum, e) => sum + e.moneySaved);
    final co2Total =
        events.fold<double>(0, (sum, e) => sum + e.co2Saved);

    final petEvents = events.where((e) => e.type == ImpactType.fedToPet).toList();
    final petQty = petEvents.fold<double>(0, (sum, e) => sum + e.quantity);
    final totalQty = events.fold<double>(0, (sum, e) => sum + e.quantity);
    final petShare = totalQty == 0 ? 0.0 : (petQty / totalQty).clamp(0.0, 1.0);

    final dailyMoney = <DateTime, double>{};
    final dailyCo2 = <DateTime, double>{};

    for (final e in events) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      dailyMoney[d] = (dailyMoney[d] ?? 0) + e.moneySaved;
      dailyCo2[d] = (dailyCo2[d] ?? 0) + e.co2Saved;
    }

    final allDates = <DateTime>{
      ...dailyMoney.keys,
      ...dailyCo2.keys,
    }.toList()
      ..sort((a, b) => a.compareTo(b));

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

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Your Impact',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 1. 顶部 Hero Card：强调 Streak，这是用户最直接的成就感来源
          _ImpactHeroCard(
            streak: streak,
            rangeLabel: _rangeLabel(_range),
          ),

          const SizedBox(height: 24),

          // 2. 时间范围选择器：放在这里作为“控制器”，控制下方的数据显示
          _buildRangeSelector(),

          const SizedBox(height: 24),

          // 3. 核心指标概览：Money & CO2
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.savings_rounded,
                  title: 'Money Saved',
                  value: '€${moneyTotal.toStringAsFixed(2)}',
                  tint: const Color(0xFF0E7AA8), // 品牌蓝
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  icon: Icons.eco_rounded,
                  title: 'CO₂ Avoided',
                  value: '${co2Total.toStringAsFixed(1)} kg',
                  tint: const Color(0xFF43A047), // 生态绿
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4. Streak 进度详情 (Gamification)
          _StreakMilestoneCard(streak: streak),

          const SizedBox(height: 32),

          // 5. 图表区：如果没数据则显示空状态
          if (events.isEmpty)
            _EmptyImpactCard()
          else ...[
             Text(
              'Trends',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            _LineChartCard(
              title: 'Money Savings',
              color: const Color(0xFF0E7AA8),
              spots: moneySpots,
              labels: labels,
              valueSuffix: '€',
            ),
            const SizedBox(height: 20),
            _LineChartCard(
              title: 'Carbon Footprint',
              color: const Color(0xFF43A047),
              spots: co2Spots,
              labels: labels,
              valueSuffix: 'kg',
            ),
          ],

          const SizedBox(height: 32),

          // 6. 宠物专属卡片 (Personalization)
          _GuineaPigCard(
            petQty: petQty,
            totalQty: totalQty,
            petShare: petShare,
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 构建更现代的 Segment Control 风格选择器
  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: ImpactRange.values.map((r) {
          final selected = r == _range;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _range = r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0E7AA8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _rangeLabel(r),
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ===================== UI Components (UX Optimized) =====================

class _ImpactHeroCard extends StatelessWidget {
  final int streak;
  final String rangeLabel;

  const _ImpactHeroCard({
    required this.streak,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        // 使用更深邃、更有质感的渐变
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
            color: const Color(0xFF2C5364).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: _GlassCircle(size: 140, opacity: 0.05),
          ),
          Positioned(
            left: 20,
            bottom: -40,
            child: _GlassCircle(size: 180, opacity: 0.05),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB74D), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Current Streak',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.emoji_events_rounded, color: Colors.white.withOpacity(0.2), size: 32),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$streak',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'days',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      streak == 0
                          ? 'Save one item today to start!'
                          : 'Consistency is key. Great job!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _GlassCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

// 极简风格的指标卡片，去掉 subtitle 减少视觉干扰
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color tint;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
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
              color: tint.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tint, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakMilestoneCard extends StatelessWidget {
  final int streak;
  const _StreakMilestoneCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    const milestones = [3, 7, 14, 30];
    final nextMilestone = milestones.firstWhere(
      (m) => m > streak,
      orElse: () => streak == 0 ? 3 : streak,
    );
    final progress = nextMilestone <= 0 ? 0.0 : (streak / nextMilestone).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Next Milestone',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[100],
              color: const Color(0xFFFFB74D), // 更有活力的橙色
            ),
          ),
          const SizedBox(height: 12),
          Text(
            streak >= nextMilestone
                ? '🔥 Amazing! You hit a $streak-day streak!'
                : 'Just ${nextMilestone - streak} more days to hit $nextMilestone days.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _EmptyImpactCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No data yet",
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            "Start cooking or feeding your pets to see your impact charts.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], height: 1.5, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// 豚鼠卡片：使用更温暖的色调，强调名字
class _GuineaPigCard extends StatelessWidget {
  final double petQty;
  final double totalQty;
  final double petShare;

  const _GuineaPigCard({
    required this.petQty,
    required this.totalQty,
    required this.petShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // 暖黄色背景，更温馨
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Little Shi & Little Yuan', // 用户个性化名字
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The Guinea Pig Loop',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5D4037).withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Items Snacked',
                        style: TextStyle(fontSize: 11, color: Colors.brown[300]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        petQty.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.brown.withOpacity(0.1),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diet Share',
                        style: TextStyle(fontSize: 11, color: Colors.brown[300]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(petShare * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5D4037),
                        ),
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

// 图表卡片：更干净，去掉了外部边框和多余线条
class _LineChartCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<FlSpot> spots;
  final Map<int, String> labels;
  final String valueSuffix;

  const _LineChartCard({
    required this.title,
    required this.color,
    required this.spots,
    required this.labels,
    required this.valueSuffix,
  });

  double _maxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 1.0;
    double m = 0;
    for (final s in spots) {
      if (s.y > m) m = s.y;
    }
    return m <= 0 ? 1.0 : (m * 1.2);
  }

  @override
  Widget build(BuildContext context) {
    final double maxX = spots.isEmpty ? 0.0 : (spots.length > 1 ? (spots.length - 1).toDouble() : 1.0);
    final double maxY = _maxY(spots);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 3,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[100], // 极淡的网格线
                      strokeWidth: 1,
                      dashArray: [4, 4], // 虚线
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                minX: 0.0,
                maxX: maxX,
                minY: 0.0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((ts) {
                        final idx = ts.x.toInt();
                        final label = labels[idx] ?? '';
                        final v = ts.y.toStringAsFixed(1);
                        return LineTooltipItem(
                          '$v $valueSuffix\n',
                          const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: label,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // 隐藏Y轴标签，保持干净，依赖点击查看数值
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        // 逻辑：只显示首尾，或者少量标签
                        if (idx == 0 || idx == labels.length - 1 || (labels.length > 4 && idx == labels.length ~/ 2)) {
                           final label = labels[idx];
                           if (label != null) {
                             return Padding(
                               padding: const EdgeInsets.only(top: 8),
                               child: Text(
                                 label,
                                 style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500),
                               ),
                             );
                           }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35, // 更平滑
                    spots: spots,
                    barWidth: 3,
                    color: color,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false), // 默认不显示点，点击才有
                    belowBarData: BarAreaData(
                      show: true,
                      // 渐变填充，让图表看起来“落地”了
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withOpacity(0.15),
                          color.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}