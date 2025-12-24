// lib/screens/impact_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import '../repositories/inventory_repository.dart';
import '../widgets/profile_avatar_button.dart';

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

  @override
  Widget build(BuildContext context) {
    final start = _rangeStart();
    
    final events = widget.repo.impactEvents
        .where((e) => !e.date.isBefore(start))
        .toList();

    final streak = widget.repo.getCurrentStreakDays();
    final savedCount = widget.repo.getSavedCount();
    
    final moneyTotal = events.fold<double>(0, (sum, e) => sum + e.moneySaved);
    final co2Total = events.fold<double>(0, (sum, e) => sum + e.co2Saved);

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

    final allDates = <DateTime>{...dailyMoney.keys, ...dailyCo2.keys}.toList()
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
    
    int ecoScore = (savedCount * 2 + streak * 5).clamp(0, 100);
    if (events.isEmpty) ecoScore = 0;

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
        actions: const [
          ProfileAvatarButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          _ImpactHeroCard(score: ecoScore, streak: streak),
          const SizedBox(height: 24),
          _SlidingRangeSelector(
            currentRange: _range,
            onChanged: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.savings_rounded,
                  title: 'Money Saved',
                  value: '€${moneyTotal.toStringAsFixed(1)}',
                  tint: const Color(0xFF0E7AA8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'CO₂ Avoided',
                  value: '${co2Total.toStringAsFixed(1)} kg',
                  tint: const Color(0xFF43A047),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 🆕 New Section: Equivalents
          if (moneyTotal > 0 || co2Total > 0)
            _ImpactEquivalentsSection(money: moneyTotal, co2: co2Total),
          
          if (moneyTotal > 0 || co2Total > 0)
            const SizedBox(height: 24),

          _BadgesSection(savedCount: savedCount),
          const SizedBox(height: 32),
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
            if (allDates.length < 2)
               _InsufficientDataCard()
            else ...[
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
          ],
          const SizedBox(height: 32),
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
}

// ===================== UI Components =====================

// 🆕 New Component: Equivalents Section
class _ImpactEquivalentsSection extends StatelessWidget {
  final double money;
  final double co2;

  const _ImpactEquivalentsSection({required this.money, required this.co2});

  @override
  Widget build(BuildContext context) {
    // Estimations: 
    // 1 Coffee ~ €3.00
    // 1 km Driving ~ 0.2 kg CO2
    final coffees = (money / 3.0).toStringAsFixed(1);
    final kmDriven = (co2 / 0.2).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'That\'s equivalent to...',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.brown.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('☕️', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(coffees, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const Text('coffees earned', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('🚗', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$kmDriven km', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const Text('driving avoided', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
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

class _ImpactHeroCard extends StatelessWidget {
  final int score;
  final int streak;

  const _ImpactHeroCard({required this.score, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E7D32), // Forest Green
            Color(0xFF005F87), // BSH Blue
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -40, top: -40, child: _GlassCircle(size: 160)),
          Positioned(left: -20, bottom: -60, child: _GlassCircle(size: 140)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ECO SCORE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$score',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '/100',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB74D), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$streak day streak!',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CustomPaint(
                    painter: _ArcPainter(
                      percent: score / 100,
                      color: Colors.white,
                      bgColor: Colors.white.withOpacity(0.15),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            score > 80 ? Icons.emoji_events : Icons.eco, 
                            color: Colors.white, 
                            size: 32
                          ),
                        ],
                      ),
                    ),
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(14),
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
                curve: Curves.easeOutCubic,
                child: Container(
                  width: itemWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
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

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color tint;

  const _MetricCard({required this.icon, required this.title, required this.value, required this.tint});

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
            style: const TextStyle(
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

class _BadgesSection extends StatelessWidget {
  final int savedCount;
  const _BadgesSection({required this.savedCount});

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Achievements',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BadgeItem(icon: Icons.egg_alt_outlined, label: 'Starter', isUnlocked: savedCount >= 1, color: Colors.blue),
              _BadgeItem(icon: Icons.eco, label: 'Saver', isUnlocked: savedCount >= 10, color: Colors.green),
              _BadgeItem(icon: Icons.volunteer_activism, label: 'Hero', isUnlocked: savedCount >= 50, color: Colors.red),
              _BadgeItem(icon: Icons.diamond_outlined, label: 'Legend', isUnlocked: savedCount >= 100, color: Colors.purple),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isUnlocked;
  final Color color;

  const _BadgeItem({required this.icon, required this.label, required this.isUnlocked, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: isUnlocked ? color.withOpacity(0.1) : Colors.grey[100],
            shape: BoxShape.circle,
            border: Border.all(color: isUnlocked ? color.withOpacity(0.5) : Colors.transparent, width: 2),
          ),
          child: Icon(icon, color: isUnlocked ? color : Colors.grey[300], size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isUnlocked ? Colors.black87 : Colors.grey[400])),
      ],
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final double maxY = spots.isEmpty ? 5.0 : spots.fold(0.0, (m, s) => s.y > m ? s.y : m) * 1.2;
    final safeMaxY = maxY <= 0 ? 5.0 : maxY;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))])),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
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
                  horizontalInterval: safeMaxY / 3,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100], strokeWidth: 1, dashArray: [4, 4]),
                ),
                borderData: FlBorderData(show: false),
                minX: 0.0,
                maxX: spots.isEmpty ? 1.0 : (spots.length - 1).toDouble(),
                minY: 0.0,
                maxY: safeMaxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((ts) {
                        return LineTooltipItem(
                          '${ts.y.toStringAsFixed(1)} $valueSuffix',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.all(12),
                    tooltipMargin: 10,
                  ),
                  handleBuiltInTouches: true,
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
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    spots: spots,
                    barWidth: 3,
                    color: color,
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
              ),
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
  const _GuineaPigCard({required this.petQty, required this.totalQty, required this.petShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // 暖黄色背景
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
                      'Little Shi & Little Yuan', // 🐹 名字
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
                      Text('Items Snacked', style: TextStyle(fontSize: 11, color: Colors.brown[300])),
                      const SizedBox(height: 4),
                      Text(
                        petQty.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF5D4037)),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.brown.withOpacity(0.1)),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diet Share', style: TextStyle(fontSize: 11, color: Colors.brown[300])),
                      const SizedBox(height: 4),
                      Text(
                        '${(petShare * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF5D4037)),
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

class _EmptyImpactCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.03))),
      child: Column(children: [Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey[300]), const SizedBox(height: 16), Text("No data yet", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800])), const SizedBox(height: 8), Text("Start cooking or feeding your pets to see your impact charts.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], height: 1.5, fontSize: 13))]),
    );
  }
}

class _InsufficientDataCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.03))),
      child: Column(children: [Icon(Icons.timeline_rounded, size: 40, color: Colors.grey[300]), const SizedBox(height: 12), Text("Collecting data...", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[700])), const SizedBox(height: 4), Text("We need at least 2 days of activity to show trends.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 12))]),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final double size;
  const _GlassCircle({required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)));
  }
}

class _ArcPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color bgColor;

  _ArcPainter({required this.percent, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 8.0;

    final bgPaint = Paint()..color = bgColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fgPaint = Paint()..color = color..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * percent;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - strokeWidth / 2), startAngle, sweepAngle, false, fgPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}