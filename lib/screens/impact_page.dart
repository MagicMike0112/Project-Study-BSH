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
        return '7 days';
      case ImpactRange.month:
        return '30 days';
      case ImpactRange.year:
        return '1 year';
    }
  }

  String _shortDate(DateTime d) => '${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final start = _rangeStart();

    // 按时间范围过滤后的事件
    final events = widget.repo.impactEvents
        .where((e) => !e.date.isBefore(start))
        .toList();

    // streak 用 repo 的统一逻辑
    final streak = widget.repo.getCurrentStreakDays();

    final moneyTotal =
        events.fold<double>(0, (sum, e) => sum + e.moneySaved);
    final co2Total =
        events.fold<double>(0, (sum, e) => sum + e.co2Saved);

    final petEvents = events.where((e) => e.type == ImpactType.fedToPet).toList();
    final petQty = petEvents.fold<double>(0, (sum, e) => sum + e.quantity);
    final totalQty = events.fold<double>(0, (sum, e) => sum + e.quantity);
    final petShare = totalQty == 0 ? 0.0 : (petQty / totalQty).clamp(0.0, 1.0);

    // 聚合成按天的数据
    final dailyMoney = <DateTime, double>{};
    final dailyCo2 = <DateTime, double>{};

    for (final e in events) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      dailyMoney[d] = (dailyMoney[d] ?? 0) + e.moneySaved;
      dailyCo2[d] = (dailyCo2[d] ?? 0) + e.co2Saved;
    }

    // 用 money+co2 的 key 合并日期，避免某一天只有其中一个导致漏点
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
      appBar: AppBar(title: const Text('Your Impact')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // 顶部 summary 卡片（质感更像你 Today 的大卡）
          _ImpactHeroCard(
            streak: streak,
            rangeLabel: _rangeLabel(_range),
          ),

          const SizedBox(height: 14),

          // Range chips（更紧凑一点）
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: ImpactRange.values.map((r) {
                final selected = r == _range;
                return ChoiceChip(
                  label: Text(_rangeLabel(r)),
                  selected: selected,
                  onSelected: (_) => setState(() => _range = r),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // 统计卡片（更像 iOS/Material3 的 “小卡片+icon 圆底”）
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.savings_outlined,
                  title: 'Saved',
                  value: '€${moneyTotal.toStringAsFixed(2)}',
                  subtitle: 'in ${_rangeLabel(_range)}',
                  tint: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'CO₂ avoided',
                  value: '${co2Total.toStringAsFixed(1)} kg',
                  subtitle: 'in ${_rangeLabel(_range)}',
                  tint: scheme.secondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _StreakCard(streak: streak),

          const SizedBox(height: 18),

          // 图表
          if (events.isEmpty)
            _EmptyImpactCard()
          else ...[
            _LineChartCard(
              title: 'Money saved',
              subtitle: 'Daily total',
              color: scheme.primary,
              spots: moneySpots,
              labels: labels,
              valueSuffix: '€',
            ),
            const SizedBox(height: 12),
            _LineChartCard(
              title: 'CO₂ avoided',
              subtitle: 'Daily total',
              color: scheme.secondary,
              spots: co2Spots,
              labels: labels,
              valueSuffix: 'kg',
            ),
          ],

          const SizedBox(height: 18),

          // Guinea Pig card（也提一点质感）
          _GuineaPigCard(
            petQty: petQty,
            totalQty: totalQty,
            petShare: petShare,
          ),
        ],
      ),
    );
  }
}

// ===================== UI Components =====================

class _ImpactHeroCard extends StatelessWidget {
  final int streak;
  final String rangeLabel;

  const _ImpactHeroCard({
    required this.streak,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    // 轻“科技感”背景（不引入资源，靠层叠半透明圆形做）
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF003B66), Color(0xFF0A6BA8)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // 背景装饰
            Positioned(
              right: -40,
              top: -30,
              child: _GlassCircle(size: 150),
            ),
            Positioned(
              left: 120,
              bottom: -60,
              child: _GlassCircle(size: 180),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: const Icon(Icons.eco, color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This $rangeLabel',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$streak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                'day streak',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          streak == 0
                              ? 'Start today — save one item to begin.'
                              : 'Keep it up — small actions add up.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
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
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final double size;
  const _GlassCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color tint;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    const milestones = [3, 7, 14, 30];
    final nextMilestone = milestones.firstWhere(
      (m) => m > streak,
      orElse: () => streak == 0 ? 3 : streak,
    );
    final progress = nextMilestone <= 0 ? 0.0 : (streak / nextMilestone).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Streaks',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Consecutive days you saved food',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$streak d',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.grey[200],
            ),
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              streak == 0
                  ? 'Start today to build your first streak.'
                  : (streak >= nextMilestone)
                      ? '🔥 Great! You hit a $streak-day streak!'
                      : 'Only ${nextMilestone - streak} more day(s) to $nextMilestone.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: milestones.map((m) {
              final unlocked = streak >= m;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: unlocked
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.10)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: unlocked
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      unlocked ? Icons.check_circle : Icons.lock_outline,
                      size: 16,
                      color: unlocked
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${m}d',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: unlocked
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.insights_outlined, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "No impact data yet.\nCook with expiring items or feed them to your pets to see progress here.",
              style: TextStyle(color: Colors.grey[700], height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6F2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.brown.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.brown.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.pets, color: Colors.brown, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The Guinea Pig Loop 🐹',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.brown,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  petQty == 0
                      ? 'Little Shi & Little Yuan are waiting for their next snack.'
                      : 'They helped you upcycle ${petQty.toStringAsFixed(0)} unit(s) of food.',
                  style: TextStyle(color: Colors.brown.shade700),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: petShare,
                    minHeight: 7,
                    color: Colors.brown,
                    backgroundColor: Colors.brown.withOpacity(0.12),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  totalQty == 0
                      ? '0% of your saved food went to pets.'
                      : '${(petShare * 100).toStringAsFixed(0)}% of saved food went to pets.',
                  style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<FlSpot> spots;
  final Map<int, String> labels;
  final String valueSuffix;

  const _LineChartCard({
    required this.title,
    required this.subtitle,
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
    if (m <= 0) return 1.0;
    // 留一点顶部空间
    return (m * 1.2);
  }

  @override
  Widget build(BuildContext context) {
    final double maxX = spots.isEmpty
        ? 0.0
        : (spots.length > 1 ? (spots.length - 1).toDouble() : 1.0);
    final double maxY = _maxY(spots);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.show_chart, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.black.withOpacity(0.06),
                        strokeWidth: 1,
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
                      // 你这里不要用 tooltipBgColor（你版本不支持）
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((ts) {
                          final idx = ts.x.toInt();
                          final label = labels[idx] ?? '';
                          final v = ts.y.toStringAsFixed(2);
                          return LineTooltipItem(
                            '$label\n$v$valueSuffix',
                            TextStyle(
                              color: Colors.grey[900],
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          final label = labels[idx];
                          if (label == null) return const SizedBox.shrink();

                          // 太多点时抽样显示
                          if (labels.length > 6) {
                            final step = (labels.length / 6).ceil();
                            if (idx % step != 0) return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      spots: spots,
                      barWidth: 3,
                      color: color,
                      dotData: FlDotData(show: spots.length <= 10),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
