// lib/screens/today_page.dart
import 'dart:ui'; // Required for ImageFilter if used elsewhere, kept for compatibility
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../widgets/inventory_components.dart';
import '../widgets/food_card.dart';
import 'select_ingredients_page.dart';
import 'cooking_calendar_page.dart';

class TodayPageWrapper extends StatefulWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;

  const TodayPageWrapper({
    super.key,
    required this.repo,
    required this.onRefresh,
  });

  @override
  State<TodayPageWrapper> createState() => _TodayPageWrapperState();
}

class _TodayPageWrapperState extends State<TodayPageWrapper> {
  final GlobalKey _aiKey = GlobalKey();
  final GlobalKey _expiringKey = GlobalKey();
  bool _didShow = false;

  Future<void> _maybeShowTutorial(BuildContext context) async {
    if (_didShow) return;
    _didShow = true;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasShown = prefs.getBool('hasShownIntro_today_v1') ?? false;
    if (!hasShown) {
      try {
        ShowCaseWidget.of(context).startShowCase([_aiKey, _expiringKey]);
        await prefs.setBool('hasShownIntro_today_v1', true);
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
        return TodayPage(
          repo: widget.repo,
          onRefresh: widget.onRefresh,
          aiKey: _aiKey,
          expiringKey: _expiringKey,
        );
      },
    );
  }
}

class TodayPage extends StatelessWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;
  final GlobalKey? aiKey;
  final GlobalKey? expiringKey;

  const TodayPage({
    super.key,
    required this.repo,
    required this.onRefresh,
    this.aiKey,
    this.expiringKey,
  });

  // BSH Palette
  static const Color _primaryBlue = Color(0xFF0E7AA8);
  static const Color _surfaceColor = Color(0xFFF5F7FA); // 冷灰背景，更干净

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

  void _showBottomSnackBar(BuildContext context, String message, {VoidCallback? onUndo}) {
    if (!context.mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 3),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1F24) : const Color(0xFF323232),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            margin: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onUndo != null)
                  GestureDetector(
                    onTap: () {
                      onUndo();
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text(
                        'UNDO',
                        style: TextStyle(
                          color: Color(0xFF81D4FA),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final bgColor = theme.scaffoldBackgroundColor;
        final expiring = repo.getExpiringItems(3)
          ..sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              'Today',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: colors.onSurface),
            ),
            centerTitle: false,
            backgroundColor: bgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            actions: [
              IconButton(
                tooltip: 'Recipe Archive',
                onPressed: () => _openRecipeArchive(context),
                icon: Icon(Icons.bookmark_border_rounded, color: colors.onSurface),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              // 1. AI Chef Button
              FadeInSlide(
                index: 0,
                child: _wrapShowcase(
                  key: aiKey,
                  title: 'AI Chef',
                  description: 'Generate recipes with your expiring items.',
                  child: BouncingButton(
                    onTap: () => _showAiRecipeFlow(context, expiring),
                    child: _buildAiButton(context), 
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Cooking Calendar Hero
              FadeInSlide(
                index: 2,
                child: BouncingButton(
                  onTap: () => _openCookingCalendar(context),
                  child: _buildCalendarHero(context),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Expiring Header
              FadeInSlide(
                index: 3,
                child: _wrapShowcase(
                  key: expiringKey,
                  title: 'Expiring Soon',
                  description: 'Tap items here to manage before they go bad.',
                  child: _buildSectionHeader(context, expiring.length),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Expiring List
              if (expiring.isEmpty)
                FadeInSlide(
                  index: 4,
                  child: _buildEmptyState(context),
                )
              else
                ...expiring.asMap().entries.map(
                  (entry) => FadeInSlide(
                    index: 4 + entry.key,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: FoodCard(
                        item: entry.value,
                        leading: _buildInventoryStyleLeading(
                          entry.value,
                          ownerLabel: _resolveOwnerLabel(entry.value),
                        ),
                        onAction: (action) async {
                          HapticFeedback.mediumImpact();
                          final item = entry.value;
                          final oldStatus = item.status;
                          await repo.recordImpactForAction(item, action);

                          FoodStatus? newStatus;
                          if (action == 'eat' || action == 'pet') {
                            newStatus = FoodStatus.consumed;
                          } else if (action == 'trash') {
                            newStatus = FoodStatus.discarded;
                          }

                          if (newStatus != null) {
                            await repo.updateStatus(item.id, newStatus);
                          }

                          if (action == 'pet' && !repo.hasShownPetWarning) {
                            await repo.markPetWarningShown();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  behavior: SnackBarBehavior.fixed,
                                  content: Text('Please ensure the food is safe for your pet!'),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          }

                          if (newStatus != null) {
                            _showBottomSnackBar(
                              context,
                              _undoLabelForAction(action, item.name),
                              onUndo: () async {
                                HapticFeedback.selectionClick();
                                await repo.updateStatus(item.id, oldStatus);
                                onRefresh();
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Future<void> _showAiRecipeFlow(BuildContext context, List<FoodItem> expiringItems) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectIngredientsPage(
          repo: repo,
          preselectedExpiring: expiringItems,
        ),
      ),
    );
    if (changed == true) onRefresh();
  }

  Future<void> _openRecipeArchive(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeArchivePage(repo: repo)),
    );
  }

  Future<void> _openCookingCalendar(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CookingCalendarPage(repo: repo)),
    );
  }

  Widget _buildInventoryStyleLeading(FoodItem item, {String? ownerLabel}) {
    final leading = _leadingIcon(item);
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: leading.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(leading.icon, color: leading.color, size: 22),
          ),
          if (ownerLabel != null && ownerLabel.isNotEmpty)
            Positioned(
              right: -4,
              bottom: -4,
              child: UserAvatarTag(
                name: ownerLabel,
                size: 16,
                currentUserName: repo.currentUserName,
              ),
            ),
        ],
      ),
    );
  }

  String? _resolveOwnerLabel(FoodItem item) {
    final name = item.ownerName?.trim();
    if (name == null || name.isEmpty) return null;
    return name == 'Me' ? repo.currentUserName : name;
  }

  _Leading _leadingIcon(FoodItem item) {
    switch (item.location) {
      case StorageLocation.fridge:
        return const _Leading(Icons.kitchen_rounded, Color(0xFF005F87));
      case StorageLocation.freezer:
        return const _Leading(Icons.ac_unit_rounded, Color(0xFF3F51B5));
      case StorageLocation.pantry:
        return const _Leading(Icons.shelves, Color(0xFF795548));
    }
  }

  Widget _buildAiButton(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = isDark
        ? [const Color(0xFF1C2530), const Color(0xFF141B24)]
        : const [Color(0xFFFFFFFF), Color(0xFFF1F6FB)];

    // Soft misty style inspired by ChatGPT
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE6ECEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF005F87).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Misty accents
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFE5F1F8).withOpacity(0.8),
              ),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : const Color(0xFFEEF6FC).withOpacity(0.7),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5F1F8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.restaurant_menu, color: Color(0xFF005F87), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Chef',
                        style: TextStyle(
                          color: isDark ? colors.onSurface : const Color(0xFF0A2B3E),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cook with expiring items',
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colors.onSurface.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHero(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF18242B), Color(0xFF0E171C)]
              : const [Color(0xFFF0F7F5), Color(0xFFE8F0FA)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE3ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -16,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFDDEDF3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -12,
            bottom: -12,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE7F4EE),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE3F2ED),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0E7AA8), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan Your Week！',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to plan meals.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface.withOpacity(0.6),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: colors.onSurface.withOpacity(0.5), size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, int count) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          'Expiring Soon',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEAEA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.green, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your fridge is fresh and organized.',
            style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _undoLabelForAction(String action, String name) {
    switch (action) {
      case 'eat':
        return 'Cooked "$name"';
      case 'pet':
        return 'Fed "$name" to pet';
      case 'trash':
        return 'Discarded "$name"';
      default:
        return 'Updated "$name"';
    }
  }
}

class _Leading {
  final IconData icon;
  final Color color;
  const _Leading(this.icon, this.color);
}

// ================== Shared Animation Widgets ==================

class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  const BouncingButton({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.enabled) {
          _controller.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (widget.enabled) {
          _controller.reverse();
          widget.onTap();
        }
      },
      onTapCancel: () {
        if (widget.enabled) _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - _controller.value,
          child: widget.child,
        ),
      ),
    );
  }
}

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int index; 
  final Duration duration;

  const FadeInSlide({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 500),
  });

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

    final delay = widget.index * 50; 
    Future.delayed(Duration(milliseconds: delay), () {
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
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _offsetAnim,
        child: widget.child,
      ),
    );
  }
}

