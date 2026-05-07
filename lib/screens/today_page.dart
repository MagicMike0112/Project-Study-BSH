import 'package:flutter/material.dart';
// lib/screens/today_page.dart
import '../utils/app_haptics.dart';
import 'package:flutter/services.dart';
import 'package:showcaseview/showcaseview.dart';
import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../utils/app_typography.dart';
import '../utils/food_icon_mapping.dart';
import '../utils/reveal_route.dart';
import '../utils/showcase_utils.dart';
import '../l10n/app_localizations.dart';
import 'package:smart_food_home/screens/cooking_calendar_page.dart';
import './select_ingredients_page.dart';

class TodayPageWrapper extends StatefulWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;
  final bool isActive;

  const TodayPageWrapper({
    super.key,
    required this.repo,
    required this.onRefresh,
    required this.isActive,
  });

  @override
  State<TodayPageWrapper> createState() => _TodayPageWrapperState();
}

class _TodayPageWrapperState extends State<TodayPageWrapper> {
  final GlobalKey _aiKey = GlobalKey();
  final GlobalKey _expiringKey = GlobalKey();
  bool _didShow = false;

  Future<void> _maybeShowTutorial(BuildContext context) async {
    await ShowcaseCoordinator.startPageShowcase(
      context: context,
      hasAttempted: _didShow,
      markAttempted: () => _didShow = true,
      isPageVisibleNow: () => mounted && widget.isActive,
      isDataReadyNow: () => !widget.repo.isLoading,
      seenPrefKey: 'hasShownIntro_today_v1',
      keys: [_aiKey, _expiringKey],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) {
        if (widget.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial(context));
        }
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

class TodayPage extends StatefulWidget {
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

  @override
  State<TodayPage> createState() => _TodayPageState();

  // Updated to match Unified Consumption Hub design
  static const Color _primaryBlue = Color(0xFF1B78FF);
  
  Widget _wrapShowcase({
    required BuildContext context,
    required GlobalKey? key,
    required String title,
    required String description,
    required Widget child,
  }) {
    return wrapWithShowcase(
      context: context,
      key: key,
      title: title,
      description: description,
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
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
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
                    child: Padding(
                      // l10n: keep fallback constant for snack action visual.
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        AppLocalizations.of(context)?.undo ?? 'UNDO',
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
      topRightRevealRoute(RecipeArchivePage(repo: repo)),
    );
  }

  Future<void> _openCookingCalendar(BuildContext context) async {
    await Navigator.push(
      context,
      topRightRevealRoute(CookingCalendarPage(repo: repo)),
    );
  }

  String _timeGreetingLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n?.todayGreetingMorning ?? 'Good morning';
    if (hour < 18) return l10n?.todayGreetingNoon ?? 'Good afternoon';
    return l10n?.todayGreetingEvening ?? 'Good evening';
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

  Widget _buildAiButton(
    BuildContext context,
    int totalItems, {
    Color? buttonShadow,
    Color? cardShadow,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFF9AA3B2) : colors.primary;
    final l10n = AppLocalizations.of(context);
    final gradientColors = isDark
        ? [const Color(0xFF1A2235), const Color(0xFF141B24)]
        : const [Color(0xFFFFFFFF), Color(0xFFF4F6FB)];

    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE6ECEA)),
        boxShadow: [
          BoxShadow(
            color: (cardShadow ?? Colors.black).withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: (buttonShadow ?? primary).withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: Container(
              width: 220,
              height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                    ? primary.withValues(alpha: 0.12)
                    : const Color(0xFFE6EEFF).withValues(alpha: 0.9),
                ),
              ),
            ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF1F6FF).withValues(alpha: 0.9),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                        child: Row(
                          children: [
                          Icon(Icons.auto_awesome, size: 16, color: primary),
                          const SizedBox(width: 6),
                          Text(
                            l10n?.todayAiChefTitle ?? 'AI Chef',
                            style: TextStyle(
                              color: primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (cardShadow ?? Colors.black).withValues(alpha: isDark ? 0.22 : 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Icon(Icons.soup_kitchen_rounded, color: primary, size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.todayWhatCanICook ?? 'What can I\ncook today?',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n?.todayBasedOnItems(totalItems) ?? 'Based on $totalItems items in your fridge.',
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (buttonShadow ?? primary).withValues(alpha: isDark ? 0.35 : 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n?.todayGenerate ?? 'Generate',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                        ],
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

  Widget _buildCalendarHero(BuildContext context, {Color? cardShadow}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final buttonGray = const Color(0xFF9AA3B2);
    final l10n = AppLocalizations.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF062C26), Color(0xFF0F1F2A)]
              : const [Color(0xFFF3FBF7), Color(0xFFEAF2FA)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE3ECEF)),
        boxShadow: [
          BoxShadow(
            color: (cardShadow ?? Colors.black).withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -12,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFDDEDF3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -16,
            bottom: -16,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE7F4EE),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE3F2ED),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: isDark ? buttonGray : Colors.teal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.todayPlanWeekTitle ?? 'Plan Your Week!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n?.todayPlanWeekSubtitle ?? 'Tap to plan meals.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface.withValues(alpha: 0.6),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: colors.onSurface.withValues(alpha: 0.5), size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, int count) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              l10n?.todayExpiringSoonTitle ?? 'Expiring Soon',
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
        ),
        Text(
          l10n?.todayViewAll ?? 'View All',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: isDark
                ? const Color(0xFF9AA3B2)
                : _primaryBlue.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringItemCard(
    BuildContext context,
    FoodItem item, {
    required void Function(String action) onAction,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    
    final urgency = _expiryBadge(item.daysToExpiry, context);
    final meta = _itemMeta(item);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2235) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        dense: true,
        minVerticalPadding: 8,
        leading: _buildExpiringLeading(item, isDark: isDark),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: urgency.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  urgency.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: urgency.foreground,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton(
          padding: EdgeInsets.zero,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          menuPadding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(Icons.more_horiz, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
          onSelected: (val) => onAction(val),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'eat',
              child: Row(
                children: [
                  const Icon(Icons.restaurant, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n?.foodActionCookEat ?? 'Cook / Eat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pet',
              child: Row(
                children: [
                  const Icon(Icons.pets, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n?.foodActionFeedPets ?? 'Feed Pets',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'trash',
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n?.foodActionDiscard ?? 'Discard',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildExpiringLeading(FoodItem item, {required bool isDark}) {
    final leading = _leadingIcon(item);
    final baseColor = leading.color;
    final assetPath = foodIconAssetForItem(item);
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: assetPath.endsWith('/default.png')
          ? Icon(leading.icon, color: baseColor, size: 26)
          : Image.asset(
              assetPath,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(leading.icon, color: baseColor, size: 26),
            ),
    );
  }

  String _itemMeta(FoodItem item) {
    return '${item.quantity} ${item.unit}';
  }

  _ExpiryBadge _expiryBadge(int daysToExpiry, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (daysToExpiry < 0) {
      return _ExpiryBadge(l10n?.todayExpired ?? 'Expired', const Color(0xFFFFE5E5), const Color(0xFFD32F2F));
    }
    if (daysToExpiry == 0) {
      return _ExpiryBadge(l10n?.todayExpiryToday ?? 'Today', const Color(0xFFFFE5E5), const Color(0xFFD32F2F));
    }
    if (daysToExpiry == 1) {
      return _ExpiryBadge(l10n?.todayOneDayLeft ?? '1 day left', const Color(0xFFFFE5E5), const Color(0xFFD32F2F));
    }
    if (daysToExpiry <= 3) {
      return _ExpiryBadge(
        l10n?.foodDaysLeft(daysToExpiry) ?? '$daysToExpiry days left',
        const Color(0xFFFFF3E0),
        const Color(0xFFF57C00),
      );
    }
    return _ExpiryBadge(
      l10n?.foodDaysLeft(daysToExpiry) ?? '$daysToExpiry days left',
      const Color(0xFFFFF9C4),
      const Color(0xFFF9A825),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
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
              color: Colors.green.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.green, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.todayAllClearTitle ?? 'All Clear!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.todayAllClearSubtitle ?? 'Your fridge is fresh and organized.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _undoLabelForAction(String action, String name, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'eat':
        return l10n?.todayUndoCooked(name) ?? 'Cooked "$name"';
      case 'pet':
        return l10n?.todayUndoFedPet(name) ?? 'Fed "$name" to pet';
      case 'trash':
        return l10n?.todayUndoDiscarded(name) ?? 'Discarded "$name"';
      default:
        return l10n?.todayUndoUpdated(name) ?? 'Updated "$name"';
    }
  }
}

class _Leading {
  final IconData icon;
  final Color color;
  const _Leading(this.icon, this.color);
}

class _TodayPageState extends State<TodayPage> {
  double _scrollOffset = 0;
  static const double _fadeToWhiteDistance = 260.0;

  double get _fadeProgress => (_scrollOffset / _fadeToWhiteDistance).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repo,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final l10n = AppLocalizations.of(context);
        final baseBg = isDark ? Colors.black : Colors.white;
        const fixedLightGradient = [Color(0xFFE3F2FD), Colors.white];
        const fixedButtonShadow = Color(0xFF8AA8CC);
        const fixedCardShadow = Color(0xFFB7CDE2);
        final gradientColors = isDark
            ? [baseBg, baseBg]
            : fixedLightGradient
                .map((c) => Color.lerp(c, baseBg, _fadeProgress) ?? c)
                .toList(growable: false);

        final totalItems = widget.repo.getActiveItems().length;
        final expiring = widget.repo.getExpiringItems(3)
          ..sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));
        final headerVisibility = (1 - (_scrollOffset / 120)).clamp(0.0, 1.0).toDouble();
        final toolbarHeight = 84 * headerVisibility;
        final topInset = MediaQuery.of(context).padding.top + toolbarHeight + 12;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: baseBg,
          appBar: AppBar(
            title: Opacity(
              opacity: headerVisibility,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    MaterialLocalizations.of(context).formatMediumDate(DateTime.now()),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                Text(
                  widget._timeGreetingLabel(context),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: kMainPageTitleFontSize + 4,
                    color: colors.onSurface,
                    letterSpacing: 0.2,
                  ),
                ),
                ],
              ),
            ),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            toolbarHeight: toolbarHeight,
            actions: [
              IgnorePointer(
                ignoring: headerVisibility < 0.05,
                child: Opacity(
                  opacity: headerVisibility,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2D33) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color.lerp(fixedButtonShadow, Colors.black, _fadeProgress)
                                    ?.withValues(alpha: isDark ? 0.35 : 0.2) ??
                                Colors.black.withValues(alpha: isDark ? 0.35 : 0.2),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: IconButton(
                        tooltip: l10n?.todayRecipeArchiveTooltip ?? 'Recipe Archive',
                        onPressed: () => widget._openRecipeArchive(context),
                        icon: Icon(Icons.bookmark_border_rounded, color: colors.onSurface),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradientColors,
                      stops: const [0.0, 0.4],
                    ),
                  ),
                ),
              ),
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.vertical) return false;
                  final next = notification.metrics.pixels.clamp(0.0, _fadeToWhiteDistance);
                  if ((next - _scrollOffset).abs() > 1.0) {
                    setState(() => _scrollOffset = next.toDouble());
                  }
                  return false;
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(24, topInset, 24, 120),
                  children: [
                    FadeInSlide(
                      index: 0,
                      child: widget._wrapShowcase(
                        context: context,
                        key: widget.aiKey,
                        title: l10n?.todayAiChefTitle ?? 'AI Chef',
                        description: l10n?.todayAiChefDescription ?? 'Use current ingredients to generate recipes.',
                        child: BouncingButton(
                          onTap: () => widget._showAiRecipeFlow(context, expiring),
                          child: widget._buildAiButton(
                            context,
                            totalItems,
                            buttonShadow: fixedButtonShadow,
                            cardShadow: fixedCardShadow,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInSlide(
                      index: 2,
                      child: BouncingButton(
                        onTap: () => widget._openCookingCalendar(context),
                        child: widget._buildCalendarHero(
                          context,
                          cardShadow: fixedCardShadow,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInSlide(
                      index: 3,
                      child: widget._wrapShowcase(
                        context: context,
                        key: widget.expiringKey,
                        title: l10n?.todayExpiringSoonTitle ?? 'Expiring Soon',
                        description: l10n?.todayExpiringSoonDescription ?? 'Quickly cook, feed pets, or discard items.',
                        child: widget._buildSectionHeader(context, expiring.length),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (expiring.isEmpty)
                      FadeInSlide(index: 4, child: widget._buildEmptyState(context))
                    else
                      ...expiring.asMap().entries.map(
                            (entry) => FadeInSlide(
                              index: 4 + entry.key,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: widget._buildExpiringItemCard(
                                  context,
                                  entry.value,
                                  onAction: (action) async {
                                    AppHaptics.success();
                                    final item = entry.value;
                                    final oldStatus = item.status;
                                    await widget.repo.recordImpactForAction(item, action);

                                    FoodStatus? newStatus;
                                    if (action == 'eat' || action == 'pet') {
                                      newStatus = FoodStatus.consumed;
                                    } else if (action == 'trash') {
                                      newStatus = FoodStatus.discarded;
                                    }

                                    if (newStatus != null) {
                                      await widget.repo.updateStatus(item.id, newStatus);
                                    }

                                    if (action == 'pet' && !widget.repo.hasShownPetWarning) {
                                      await widget.repo.markPetWarningShown();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            behavior: SnackBarBehavior.fixed,
                                            content: Text(l10n?.todayPetSafetyWarning ?? 'Please ensure the food is safe for your pet!'),
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    }

                                    if (!context.mounted) return;
                                    if (newStatus != null) {
                                      widget._showBottomSnackBar(
                                        context,
                                        widget._undoLabelForAction(action, item.name, context),
                                        onUndo: () async {
                                          AppHaptics.selection();
                                          await widget.repo.updateStatus(item.id, oldStatus);
                                          widget.onRefresh();
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
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpiryBadge {
  final String label;
  final Color background;
  final Color foreground;

  const _ExpiryBadge(this.label, this.background, this.foreground);
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
          AppHaptics.selection();
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






