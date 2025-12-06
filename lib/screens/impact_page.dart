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

  @override
  Widget build(BuildContext context) {
    final start = _rangeStart();

    // 按时间范围过滤后的事件（用于图表 + 本期统计）
    final events = widget.repo.impactEvents
        .where((e) => !e.date.isBefore(start))
        .toList();

    // 所有事件（用于 streak 计算）
    final allEvents = widget.repo.impactEvents;

    final moneyTotal =
        events.fold<double>(0, (sum, e) => sum + e.moneySaved);
    final co2Total =
        events.fold<double>(0, (sum, e) => sum + e.co2Saved);

    final petEvents = events
        .where((e) => e.type == ImpactType.fedToPet)
        .toList();
    final petQty =
        petEvents.fold<double>(0, (sum, e) => sum + e.quantity);
    final totalQty =
        events.fold<double>(0, (sum, e) => sum + e.quantity);
    final petShare = totalQty == 0 ? 0.0 : petQty / totalQty;

    // ---- Streak 计算：最近连续多少天有事件 ----
    int streak = 0;
    if (allEvents.isNotEmpty) {
      final now = DateTime.now();
      DateTime cur = DateTime(now.year, now.month, now.day);

      while (true) {
        final hasEventThisDay = allEvents.any((e) {
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          return d == cur;
        });

        if (hasEventThisDay) {
          streak++;
          cur = cur.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // 聚合成按天的数据，用于画折线
    final dailyMoney = <DateTime, double>{};
    final dailyCo2 = <DateTime, double>{};

    for (final e in events) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      dailyMoney[d] = (dailyMoney[d] ?? 0) + e.moneySaved;
      dailyCo2[d] = (dailyCo2[d] ?? 0) + e.co2Saved;
    }

    final sortedDates = dailyMoney.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final moneySpots = <FlSpot>[];
    final co2Spots = <FlSpot>[];
    final labels = <int, String>{};

    for (var i = 0; i < sortedDates.length; i++) {
      final d = sortedDates[i];
      final x = i.toDouble();
      moneySpots.add(FlSpot(x, dailyMoney[d] ?? 0));
      co2Spots.add(FlSpot(x, dailyCo2[d] ?? 0));
      labels[i] = '${d.month}/${d.day}';
    }

    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final secondary = scheme.secondaryContainer;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Impact')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Sustainability Report",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "See how much you saved in food cost and CO₂ over time.",
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            "Current streak: $streak day${streak == 1 ? '' : 's'} 🔥",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // 时间范围选择
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: ImpactRange.values.map((r) {
              final selected = r == _range;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(_rangeLabel(r)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _range = r);
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 顶部统计卡片
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.savings,
                  value: '€${moneyTotal.toStringAsFixed(2)}',
                  label: 'Saved',
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  icon: Icons.cloud_off,
                  value: '${co2Total.toStringAsFixed(1)} kg',
                  label: 'CO₂ avoided',
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 图表区域
          if (events.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "No impact data yet.\nCook with expiring items or feed them to your pets to see your progress here.",
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            _LineChartCard(
              title: 'Money saved over time',
              color: primary,
              spots: moneySpots,
              labels: labels,
              valueSuffix: '€',
            ),
            const SizedBox(height: 16),
            _LineChartCard(
              title: 'CO₂ avoided over time',
              color: secondary,
              spots: co2Spots,
              labels: labels,
              valueSuffix: 'kg',
            ),
          ],
          const SizedBox(height: 24),

          // 豚鼠卡片 🐹
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.brown.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "The Guinea Pig Loop 🐹",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.brown,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        petQty == 0
                            ? "Little Shi & Little Yuan are waiting for their next snack."
                            : "Little Shi & Little Yuan helped you upcycle ${petQty.toStringAsFixed(0)} units of food instead of wasting them.",
                        style:
                            TextStyle(color: Colors.brown.shade700),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: petShare,
                        color: Colors.brown,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalQty == 0
                            ? "0% of your saved food went to pets."
                            : "${(petShare * 100).toStringAsFixed(0)}% of saved food went to pets.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.brown.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.pets,
                    size: 48, color: Colors.brown),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 小统计卡片
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final MaterialColor color;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color.shade700),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
          Text(label, style: TextStyle(color: color.shade700)),
        ],
      ),
    );
  }
}

// 折线图卡片
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
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((ts) {
                            final x = ts.x.toInt();
                            final label = labels[x] ?? '';
                            final v = ts.y.toStringAsFixed(2);
                            return LineTooltipItem(
                              '$label\n$v$valueSuffix',
                              TextStyle(color: color),
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
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            final label = labels[idx];
                            if (label == null) {
                              return const SizedBox.shrink();
                            }
                            if (labels.length > 6 &&
                                idx % (labels.length ~/ 6 + 1) != 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    minX: 0,
                    maxX: spots.isEmpty
                        ? 0
                        : spots.length > 1
                            ? (spots.length - 1).toDouble()
                            : 1,
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        spots: spots,
                        barWidth: 3,
                        color: color,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
