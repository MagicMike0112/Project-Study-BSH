// lib/screens/impact_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../models/food_item.dart'; 
import '../repositories/inventory_repository.dart';
import '../utils/impact_helpers.dart'; 
import '../widgets/profile_avatar_button.dart'; 
import 'weekly_report_page.dart'; 

enum ImpactRange { week, month, year }

class ImpactPageWrapper extends StatefulWidget {
  final InventoryRepository repo;

  const ImpactPageWrapper({super.key, required this.repo});

  @override
  State<ImpactPageWrapper> createState() => _ImpactPageWrapperState();
}

class _ImpactPageWrapperState extends State<ImpactPageWrapper> {
  final GlobalKey _weeklyKey = GlobalKey();
  final GlobalKey _rangeKey = GlobalKey();
  final GlobalKey _heroKey = GlobalKey();
  bool _didShow = false;

  Future<void> _maybeShowTutorial(BuildContext context) async {
    if (_didShow) return;
    _didShow = true;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasShown = prefs.getBool('hasShownIntro_impact_v1') ?? false;
    if (!hasShown) {
      try {
        ShowCaseWidget.of(context).startShowCase([_weeklyKey, _rangeKey, _heroKey]);
        await prefs.setBool('hasShownIntro_impact_v1', true);
      } catch (e) {
        debugPrint('Showcase error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial(context));
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
  Widget _wrapShowcase({
    required GlobalKey? key,
    required String title,
    required String description,
    required Widget child,
  }) {
    if (key == null) return child;
    return Showcase(
      key: key,
      title: title,
      description: description,
      targetBorderRadius: BorderRadius.circular(16),
      child: child,
    );
  }

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

  static const Color _moneyColor = Color(0xFF2D3436); 
  static const Color _accentColor = Color(0xFF005F87);

  void _changeRange(ImpactRange r) {
    HapticFeedback.lightImpact();
    setState(() => _range = r);
  }

  // 🟢 智能分类推断逻辑
  String _inferCategory(String? cat, String? name) {
    final c = (cat ?? '').toLowerCase();
    final n = (name ?? '').toLowerCase();

    // 1. 优先匹配 Category 关键词
    if (c.contains('veg') || c.contains('salad')) return 'Veggies';
    if (c.contains('fruit') || c.contains('berry')) return 'Fruits';
    if (c.contains('meat') || c.contains('beef') || c.contains('pork') || c.contains('chicken') || c.contains('fish')) return 'Protein';
    if (c.contains('dairy') || c.contains('cheese') || c.contains('milk') || c.contains('yogurt')) return 'Dairy';
    if (c.contains('bread') || c.contains('rice') || c.contains('pasta') || c.contains('noodle') || c.contains('cereal')) return 'Carbs';
    if (c.contains('snack') || c.contains('chip') || c.contains('chocolate')) return 'Snacks';
    if (c.contains('drink') || c.contains('beverage') || c.contains('juice') || c.contains('coffee') || c.contains('tea')) return 'Drinks';

    // 2. 如果 Category 没匹配到，尝试匹配 Name 关键词
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
    return c; 
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
        final recentEvents = List<ImpactEvent>.from(events)
          ..sort((a, b) => b.date.compareTo(a.date));
        final recent = recentEvents.take(5).toList();

        // --- Top Savers ---
        final categoryMap = <String, double>{};
        for (var e in events) {
          if (e.type == ImpactType.eaten) {
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

        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 100.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  elevation: 0,
                  systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    'Your Impact',
                    style: TextStyle(
                      color: colors.onSurface,
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
                        child: _wrapShowcase(
                          key: widget.weeklyKey,
                          title: 'Weekly Report',
                          description: 'AI summary and insights for your week.',
                          child: _WeeklyReportBanner(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WeeklyReportPage(repo: widget.repo),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      FadeInSlide(
                        index: 1,
                        child: _wrapShowcase(
                          key: widget.rangeKey,
                          title: 'Range Selector',
                          description: 'Switch between 7 days, 30 days, and 1 year.',
                          child: _SlidingRangeSelector(
                            currentRange: _range,
                            onChanged: _changeRange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      FadeInSlide(
                        index: 2,
                        child: _wrapShowcase(
                          key: widget.heroKey,
                          title: 'Impact Summary',
                          description: 'Money saved and meals rescued in this range.',
                          child: _ImpactHeroCard(
                            moneySaved: moneyTotal,
                            savedCount: savedCount,
                            rangeMode: _range.name, 
                          ),
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

                      if (recent.isNotEmpty) ...[
                        FadeInSlide(
                          index: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recent Actions',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface.withOpacity(0.75),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...recent.map(
                                (e) => _RecentActionTile(
                                  event: e,
                                  actorName: widget.repo.resolveUserNameById(e.userId),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (topCategories.isNotEmpty) ...[
                        FadeInSlide(
                          index: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top Savers',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface.withOpacity(0.75),
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
                        index: 6,
                        child: _GuineaPigCard(
                          petQty: petQty,
                          petShare: petShare,
                        ),
                      ),

                      const SizedBox(height: 32),

                      if (hasEnoughData) ...[
                        FadeInSlide(
                          index: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Savings Trend',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface.withOpacity(0.75),
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
                        FadeInSlide(index: 7, child: _EmptyStateCard()),
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

class _RecentActionTile extends StatelessWidget {
  final ImpactEvent event;
  final String? actorName;
  const _RecentActionTile({required this.event, required this.actorName});

  String _actionLabel(ImpactType type) {
    switch (type) {
      case ImpactType.eaten:
        return 'Cooked';
      case ImpactType.fedToPet:
        return 'Fed to pet';
      case ImpactType.trash:
        return 'Wasted';
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
    final action = _actionLabel(event.type);
    final color = _actionColor(event.type);
    final name = actorName ?? 'Family';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
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
          event.itemName ?? 'Item',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        subtitle: Text(
          action,
          style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6)),
        ),
        trailing: Text(
          '${event.quantity.toStringAsFixed(1)} ${event.unit}',
          style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6)),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.purple.withOpacity(0.1),
            width: 1.5,
          ),
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
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Recap Ready',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'Tap to view your diet insights',
                    style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.6)),
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
            Color(0xFF0B5F87),
            Color(0xFF0F7AA8),
            Color(0xFF3BA7C4),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F7AA8).withOpacity(0.25),
            blurRadius: 22,
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
            style: const TextStyle(color: Color(0xFFD6F2F6), fontSize: 13, fontWeight: FontWeight.w500),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colors.onSurface,
                    ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
              color: colors.onSurface.withOpacity(0.6),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.orange.withOpacity(0.1),
          width: 1.5,
        ),
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
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enjoyed ${petQty.toStringAsFixed(1)}kg of leftovers',
                  style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.65)),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final double maxY = spots.isEmpty ? 5.0 : spots.fold(0.0, (m, s) => s.y > m ? s.y : m) * 1.2;
    final safeMaxY = maxY <= 0 ? 5.0 : maxY;

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
              color: colors.onSurface.withOpacity(0.08),
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
                    // 🟢 修复：使用 meta 参数替代 axisSide
                    return SideTitleWidget(
                      meta: meta, 
                      space: 4,
                      child: Text(
                        labels[idx] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface.withOpacity(0.5),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 48, color: colors.onSurface.withOpacity(0.25)),
          const SizedBox(height: 16),
          Text(
            "No data yet",
            style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Start saving food to see your impact!",
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: 13),
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
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceVariant.withOpacity(0.4) : Colors.grey[200],
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
                    color: theme.cardColor,
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
                            color: isSelected
                                ? colors.onSurface
                                : colors.onSurface.withOpacity(0.6),
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
