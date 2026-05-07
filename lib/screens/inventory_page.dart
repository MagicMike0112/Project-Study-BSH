// lib/screens/inventory_page.dart
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/app_haptics.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../l10n/app_localizations.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../utils/app_typography.dart';
import '../utils/food_icon_mapping.dart';
import '../utils/showcase_utils.dart';
import 'add_food_page.dart';
import 'inventory_item_detail_page.dart';
import '../widgets/animations.dart';
import '../widgets/inventory_components.dart';
import '../widgets/pull_to_refresh_cue.dart';
import 'family_page.dart';

typedef AppSnackBarFn = void Function(String message, {VoidCallback? onUndo});

enum _Urgency { expired, today, soon, ok, none }
enum _MoveEffect { freeze, thaw }

class _Leading {
  final IconData icon;
  final Color color;
  const _Leading(this.icon, this.color);
}

class _MoveEffectOverlay extends StatelessWidget {
  final double progress;
  final _MoveEffect type;
  final BorderRadius borderRadius;

  const _MoveEffectOverlay({
    required this.progress,
    required this.type,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isFreeze = type == _MoveEffect.freeze;
    final glowColor = isFreeze ? const Color(0xFF4FC3F7) : const Color(0xFFFFB74D);
    final glowOpacity = (1.0 - progress).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Opacity(
            opacity: glowOpacity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          CustomPaint(
            painter: _MoveParticlePainter(
              progress: progress,
              color: glowColor,
              type: type,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  final _MoveEffect type;

  _MoveParticlePainter({
    required this.progress,
    required this.color,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = progress.clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    if (type == _MoveEffect.freeze) {
      final count = 22;
      final maxRadius = size.shortestSide * 0.45;
      for (int i = 0; i < count; i++) {
        final wobble = (math.sin(i * 1.7) * 0.08);
        final angle = (2 * math.pi / count) * i + wobble;
        final radius = maxRadius * (0.55 + t * 0.45);
        final p = Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        );
        final sizeFactor = (1.0 - t) * (0.6 + (i % 5) * 0.08);
        paint.color = color.withValues(alpha: 0.45 * sizeFactor);
        canvas.drawCircle(p, 3.5 * sizeFactor + 0.8, paint);
        // extra sparkle dots
        if (i.isEven) {
          final dot = Offset(p.dx + math.cos(angle) * 6, p.dy + math.sin(angle) * 6);
          paint.color = color.withValues(alpha: 0.25 * sizeFactor);
          canvas.drawCircle(dot, 2.0 * sizeFactor, paint);
        }
      }
    } else {
      final count = 12;
      for (int i = 0; i < count; i++) {
        final drift = math.sin((i + 1) * 1.3) * 0.03;
        final x = size.width * (0.18 + i * 0.06 + drift);
        final y = size.height * (0.08 + t * 0.8 + i * 0.015);
        final drop = Offset(x, y.clamp(0, size.height));
        final alpha = (1.0 - t);
        paint.color = color.withValues(alpha: 0.5 * alpha);
        canvas.drawCircle(drop, 3.2 * alpha + 1.8, paint);
        final tail = Rect.fromLTWH(drop.dx - 1, drop.dy - 10, 2, 12);
        paint.color = color.withValues(alpha: 0.28 * alpha);
        canvas.drawRRect(
          RRect.fromRectAndRadius(tail, const Radius.circular(2)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MoveParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.type != type || oldDelegate.color != color;
  }
}

class _InventoryViewData {
  final List<FoodItem> fridgeItems;
  final List<FoodItem> freezerItems;
  final List<FoodItem> pantryItems;
  final List<String> sortedUsers;
  final bool hasAnyItems;
  final bool hasSearchResults;
  final bool isSearching;
  final bool isSharedMode;
  final String currentUserName;

  const _InventoryViewData({
    required this.fridgeItems,
    required this.freezerItems,
    required this.pantryItems,
    required this.sortedUsers,
    required this.hasAnyItems,
    required this.hasSearchResults,
    required this.isSearching,
    required this.isSharedMode,
    required this.currentUserName,
  });

  factory _InventoryViewData.empty() => const _InventoryViewData(
    fridgeItems: [],
    freezerItems: [],
    pantryItems: [],
    sortedUsers: [],
    hasAnyItems: false,
    hasSearchResults: false,
    isSearching: false,
    isSharedMode: false,
    currentUserName: '',
  );
}

class InventoryPageWrapper extends StatelessWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;
  final AppSnackBarFn showSnackBar;
  final bool isActive;

  const InventoryPageWrapper({
    super.key,
    required this.repo,
    required this.onRefresh,
    required this.showSnackBar,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => InventoryPage(
        repo: repo,
        onRefresh: onRefresh,
        showSnackBar: showSnackBar,
        isActive: isActive,
      ),
    );
  }
}

class InventoryPage extends StatefulWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;
  final AppSnackBarFn showSnackBar;
  final bool isActive;

  const InventoryPage({
    super.key,
    required this.repo,
    required this.onRefresh,
    required this.showSnackBar,
    required this.isActive,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _swipeDeleteKey = GlobalKey();
  final GlobalKey _longPressMenuKey = GlobalKey();
  bool _didShowTutorial = false;
  bool _didCheckGestureHint = false;
  static const String _autoCategoryKey = '__auto__';
  static const List<_CategoryOption> _categoryOptions = [
    _CategoryOption('produce', 'Produce', Icons.eco_rounded, Color(0xFF66BB6A)),
    _CategoryOption('dairy', 'Dairy', Icons.water_drop_rounded, Color(0xFF42A5F5)),
    _CategoryOption('meat', 'Meat', Icons.restaurant_rounded, Color(0xFFEF5350)),
    _CategoryOption('seafood', 'Seafood', Icons.set_meal_rounded, Color(0xFF5C6BC0)),
    _CategoryOption('bakery', 'Bakery', Icons.bakery_dining_rounded, Color(0xFFFFB300)),
    _CategoryOption('frozen', 'Frozen', Icons.ac_unit_rounded, Color(0xFF4DD0E1)),
    _CategoryOption('beverage', 'Beverage', Icons.local_drink_rounded, Color(0xFF26A69A)),
    _CategoryOption('pantry', 'Pantry', Icons.kitchen_rounded, Color(0xFFFFA726)),
    _CategoryOption('snacks', 'Snacks', Icons.cookie_rounded, Color(0xFFFF7043)),
    _CategoryOption('household', 'Household', Icons.cleaning_services_rounded, Color(0xFF78909C)),
    _CategoryOption('pet', 'Pet', Icons.pets_rounded, Color(0xFF8D6E63)),
  ];

  String _selectedUser = 'All';
  _InventoryViewData _viewData = _InventoryViewData.empty();

  final Map<StorageLocation, bool> _sectionExpanded = {
    StorageLocation.fridge: true,
    StorageLocation.freezer: true,
    StorageLocation.pantry: true,
  };
  bool _didFireRefreshThresholdHaptic = false;
  double _refreshPullDistance = 0;
  double _refreshVisualProgress = 0;
  bool _refreshVisualArmed = false;
  AnimationController? _fxController;
  String? _fxItemId;
  _MoveEffect? _fxType;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _viewData = _computeViewData();
    widget.repo.addListener(_onRepoChanged);
    _fxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _fxItemId = null;
          _fxType = null;
        });
      }
    });
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowTutorial());
    }
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowTutorial());
      _maybeShowGestureHint();
    }
  }

  Future<void> _checkAndShowTutorial() async {
    final keys = <GlobalKey>[_searchKey];
    if (_viewData.hasAnyItems) {
      keys.addAll([_swipeDeleteKey, _longPressMenuKey]);
    }
    await ShowcaseCoordinator.startPageShowcase(
      context: context,
      hasAttempted: _didShowTutorial,
      markAttempted: () => _didShowTutorial = true,
      isPageVisibleNow: () => mounted && widget.isActive,
      isDataReadyNow: () => !widget.repo.isLoading || _viewData.hasAnyItems,
      seenPrefKey: 'hasShownIntro_v7',
      keys: keys,
    );
  }

  Future<void> _checkAndShowGestureHint(bool hasItems) async {
    if (!widget.isActive) return;
    if (!hasItems) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasShownHint = prefs.getBool('hasShownGestureHint_v3') ?? false;
    if (!hasShownHint) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && widget.isActive) {
          _showToast('Tip: Tap the Snowflake/Fire icon to move items fast!');
          prefs.setBool('hasShownGestureHint_v3', true);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fxController?.dispose();
    widget.repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _showToast(String message, {VoidCallback? onUndo}) {
    widget.showSnackBar(message, onUndo: onUndo);
  }

  void _onRepoChanged() {
    if (!mounted) return;
    setState(() => _viewData = _computeViewData());
    _maybeShowGestureHint();
  }

  void _updateSearchQuery(String value) {
    setState(() {
      _searchQuery = value;
      _viewData = _computeViewData();
    });
    _maybeShowGestureHint();
  }

  void _setSelectedUser(String user) {
    setState(() {
      _selectedUser = user;
      _viewData = _computeViewData();
    });
    _maybeShowGestureHint();
  }

  void _maybeShowGestureHint() {
    if (!widget.isActive) return;
    if (_didCheckGestureHint) return;
    if (_viewData.hasAnyItems && _searchQuery.isEmpty) {
      _didCheckGestureHint = true;
      _checkAndShowGestureHint(true);
    }
  }

  Future<void> _onRefreshWithFeedback() async {
    await widget.repo.refreshAll();
    if (!mounted) return;
    setState(() {
      _refreshVisualProgress = 0;
      _refreshVisualArmed = false;
    });
    AppHaptics.success();
  }

  bool _handleRefreshPullNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollStartNotification) {
      _refreshPullDistance = 0;
      _didFireRefreshThresholdHaptic = false;
      return false;
    }

    if (notification.metrics.extentBefore > 0) return false;

    if (notification is OverscrollNotification) {
      _refreshPullDistance += notification.overscroll.abs();
    } else if (notification is ScrollUpdateNotification && notification.dragDetails != null) {
      final delta = notification.scrollDelta ?? 0;
      if (delta < 0) _refreshPullDistance += -delta;
    }

    final armed = _refreshPullDistance >= 88;
    final visualProgress = (_refreshPullDistance / 88).clamp(0.0, 1.2);
    if ((visualProgress - _refreshVisualProgress).abs() > 0.04 || armed != _refreshVisualArmed) {
      setState(() {
        _refreshVisualProgress = visualProgress.toDouble();
        _refreshVisualArmed = armed;
      });
    }

    if (!_didFireRefreshThresholdHaptic && armed) {
      _didFireRefreshThresholdHaptic = true;
      AppHaptics.selection();
    }

    if (notification is ScrollEndNotification) {
      _refreshPullDistance = 0;
      _didFireRefreshThresholdHaptic = false;
      if (_refreshVisualProgress != 0 || _refreshVisualArmed) {
        setState(() {
          _refreshVisualProgress = 0;
          _refreshVisualArmed = false;
        });
      }
    }
    return false;
  }

  _InventoryViewData _computeViewData() {
    final allItems = widget.repo.getActiveItems();
    final isSharedMode = widget.repo.isSharedUsage;
    final currentUserName = widget.repo.currentUserName;

    // NOTE: legacy comment cleaned.
    Set<String> allUsers = {};
    if (isSharedMode) {
      allUsers = {'All'};
    } else {
      allUsers = {'All', currentUserName};
      for (var item in allItems) {
        final owner = _resolveOwnerLabel(item.ownerName, currentUserName);
        if (owner.isNotEmpty && owner != 'Family') {
          allUsers.add(owner);
        }
      }
    }

    final sortedUsers = allUsers.toList()
      ..sort((a, b) {
        if (a == 'All') return -1;
        if (b == 'All') return 1;
        if (a == currentUserName) return -1;
        if (b == currentUserName) return 1;
        return a.compareTo(b);
      });

    // NOTE: legacy comment cleaned.
    final searchLower = _searchQuery.toLowerCase();
    var resolvedUser = _selectedUser;

    // NOTE: legacy comment cleaned.
    if (!isSharedMode && resolvedUser != 'All') {
      if (resolvedUser == 'Family' || resolvedUser == 'Shared') {
        resolvedUser = currentUserName;
      }
      if (resolvedUser == 'Me') {
        resolvedUser = currentUserName;
      }
    }

    // NOTE: legacy comment cleaned.
    final filteredList = allItems.where((item) {
      // NOTE: legacy comment cleaned.
      if (searchLower.isNotEmpty && !item.name.toLowerCase().contains(searchLower)) {
        return false;
      }

      // NOTE: legacy comment cleaned.
      if (!isSharedMode) {
        // NOTE: legacy comment cleaned.
        if (item.ownerName == 'Family') return false;

        if (resolvedUser != 'All') {
          final owner = _resolveOwnerLabel(item.ownerName, currentUserName);
          if (owner != resolvedUser) return false;
        }
      }
      return true;
    }).toList();

    // NOTE: legacy comment cleaned.
    if (resolvedUser != _selectedUser && _selectedUser != 'All' && _selectedUser != 'Family' && _selectedUser != 'Me') {
      // NOTE: legacy comment cleaned.
    }

    // NOTE: legacy comment cleaned.
    filteredList.sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));

    // NOTE: legacy comment cleaned.
    final fridgeItems = <FoodItem>[];
    final freezerItems = <FoodItem>[];
    final pantryItems = <FoodItem>[];

    for (var item in filteredList) {
      switch (item.location) {
        case StorageLocation.fridge:
          fridgeItems.add(item);
          break;
        case StorageLocation.freezer:
          freezerItems.add(item);
          break;
        case StorageLocation.pantry:
          pantryItems.add(item);
          break;
      }
    }

    final hasAnyItems = allItems.isNotEmpty;
    final hasSearchResults = filteredList.isNotEmpty;
    final isSearching = _searchQuery.isNotEmpty;

    return _InventoryViewData(
      fridgeItems: fridgeItems,
      freezerItems: freezerItems,
      pantryItems: pantryItems,
      sortedUsers: sortedUsers,
      hasAnyItems: hasAnyItems,
      hasSearchResults: hasSearchResults,
      isSearching: isSearching,
      isSharedMode: isSharedMode,
      currentUserName: currentUserName,
    );
  }

  String _resolveOwnerLabel(String? ownerName, String currentUserName) {
    if (ownerName == null || ownerName.isEmpty) return 'Unknown';
    if (ownerName == 'Me') return currentUserName;
    return ownerName;
  }

  Future<void> _quickMoveItem(FoodItem item, StorageLocation target) async {
    AppHaptics.success();
    final oldLocation = item.location;
    final effect = target == StorageLocation.freezer ? _MoveEffect.freeze : _MoveEffect.thaw;
    _triggerMoveEffect(item.id, effect);
    // Give the overlay time to show before the item moves sections.
    await Future.delayed(const Duration(milliseconds: 260));

    await widget.repo.updateItem(item.copyWith(location: target));
    if (!mounted) return;

    final action = target == StorageLocation.freezer ? "Frozen" : "Defrosted";
    _showToast(
      '$action "${item.name}"',
      onUndo: () => widget.repo.updateItem(item.copyWith(location: oldLocation)),
    );
  }

  void _triggerMoveEffect(String itemId, _MoveEffect effect) {
    if (_fxController == null) return;
    setState(() {
      _fxItemId = itemId;
      _fxType = effect;
    });
    _fxController!.forward(from: 0);
  }

  Future<void> _assignOwner(FoodItem item, String newOwnerName) async {
    AppHaptics.success();
    await widget.repo.assignItemToUser(item.id, newOwnerName);
    if (!mounted) return;
    _showToast("Assigned to $newOwnerName");
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final data = _viewData;
    final hasAnyItems = data.hasAnyItems;
    final isSearching = data.isSearching;
    final hasSearchResults = data.hasSearchResults;
    final isSharedMode = data.isSharedMode;
    final currentUserName = data.currentUserName;
    final sortedUsers = data.sortedUsers;
    final fridgeItems = data.fridgeItems;
    final freezerItems = data.freezerItems;
    final pantryItems = data.pantryItems;
    final showcaseItemId = _searchQuery.isEmpty
        ? (fridgeItems.isNotEmpty
            ? fridgeItems.first.id
            : freezerItems.isNotEmpty
                ? freezerItems.first.id
                : pantryItems.isNotEmpty
                    ? pantryItems.first.id
                    : null)
        : null;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final refreshAccent = colors.onSurfaceVariant;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n?.navInventory ?? 'Inventory',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            fontSize: kMainPageTitleFontSize,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        actions: [
          Semantics(
            button: true,
            label: widget.repo.hasPendingUploads
                ? (l10n?.inventorySyncChangesLabel ?? 'Sync changes to cloud')
                : (l10n?.inventoryCloudSyncStatusLabel ?? 'Cloud sync status'),
            hint: widget.repo.hasPendingUploads
                ? (l10n?.inventorySyncRetryHint ?? 'Tap to retry syncing pending changes')
                : (l10n?.inventorySyncAllSavedHint ?? 'Tap to confirm all changes are saved'),
            child: IconButton(
              icon: widget.repo.hasPendingUploads
                  ? const Icon(Icons.cloud_upload_outlined, size: 24, color: Colors.orange)
                  : const Icon(Icons.cloud_done_rounded, size: 24, color: Colors.green),
              tooltip: widget.repo.hasPendingUploads
                  ? (l10n?.inventorySyncingChanges ?? 'Syncing changes...')
                  : (l10n?.inventoryAllChangesSaved ?? 'All changes saved'),
              onPressed: () {
                if (widget.repo.hasPendingUploads) {
                  widget.showSnackBar(l10n?.inventorySyncingChangesToCloud ?? 'Syncing changes to cloud...');
                  widget.repo.refreshAll();
                } else {
                  widget.showSnackBar(l10n?.inventoryAllSavedToCloud ?? 'All changes saved to cloud.');
                }
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: Colors.transparent,
            backgroundColor: Colors.transparent,
            strokeWidth: 0.1,
            elevation: 0,
            onRefresh: _onRefreshWithFeedback,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleRefreshPullNotification,
              child: (widget.repo.isLoading && !hasAnyItems)
            ? const Center(child: CircularProgressIndicator())
            : !hasAnyItems
            ? CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context),
            ),
          ],
        )
            : CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: wrapWithShowcase(
                      context: context,
                      key: _searchKey,
                      title: l10n?.inventoryQuickSearchTitle ?? 'Quick Search',
                      description: l10n?.inventoryQuickSearchDescription ?? 'Find any item by name in seconds.',
                      child: _buildSearchBar(),
                    ),
                  ),

                  if (!isSharedMode)
                    Container(
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: sortedUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        addSemanticIndexes: false,
                        itemBuilder: (context, index) {
                          final user = sortedUsers[index];
                          final isSelected = _selectedUser == user;
                          return UserFilterChip(
                            label: user,
                            isSelected: isSelected,
                            onTap: () {
                              AppHaptics.selection();
                              _setSelectedUser(user);
                            },
                            currentUserName: currentUserName,
                          );
                        },
                      ),
                    ),

                ],
              ),
            ),

            if (isSearching && !hasSearchResults)
              SliverToBoxAdapter(child: _buildNoSearchResults()),

            if (fridgeItems.isNotEmpty)
              _buildSliverSection(
                title: l10n?.foodLocationFridge ?? 'Fridge',
                icon: Icons.kitchen_rounded,
                color: const Color(0xFF005F87),
                items: fridgeItems,
                location: StorageLocation.fridge,
                sortedUsers: sortedUsers,
                isSharedMode: isSharedMode,
                currentUserName: currentUserName,
                showcaseItemId: showcaseItemId,
              ),

            if (freezerItems.isNotEmpty)
              _buildSliverSection(
                title: l10n?.foodLocationFreezer ?? 'Freezer',
                icon: Icons.ac_unit_rounded,
                color: const Color(0xFF3F51B5),
                items: freezerItems,
                location: StorageLocation.freezer,
                sortedUsers: sortedUsers,
                isSharedMode: isSharedMode,
                currentUserName: currentUserName,
                showcaseItemId: showcaseItemId,
              ),

            if (pantryItems.isNotEmpty)
              _buildSliverSection(
                title: l10n?.foodLocationPantry ?? 'Pantry',
                icon: Icons.shelves,
                color: Colors.brown,
                items: pantryItems,
                location: StorageLocation.pantry,
                sortedUsers: sortedUsers,
                isSharedMode: isSharedMode,
                currentUserName: currentUserName,
                showcaseItemId: showcaseItemId,
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
            ),
          ),
          PullToRefreshCue(
            progress: _refreshVisualProgress,
            armed: _refreshVisualArmed,
            color: refreshAccent,
            hintText: l10n?.pullToRefreshHint ?? 'Pull to refresh',
            releaseText: l10n?.pullToRefreshRelease ?? 'Release to refresh',
          ),
        ],
        ),
    );
  }

  Widget _buildSliverSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<FoodItem> items,
    required StorageLocation location,
    required List<String> sortedUsers,
    required bool isSharedMode,
    required String currentUserName,
    required String? showcaseItemId,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isExpanded = _sectionExpanded[location] ?? true;
    final indexMap = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      indexMap[items[i].id] = i;
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: InkWell(
            onTap: () {
              AppHaptics.selection();
              setState(() => _sectionExpanded[location] = !isExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (isExpanded)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final item = items[index];
                  return RepaintBoundary(
                    key: ValueKey(item.id),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildDismissibleItem(
                        context,
                        item,
                        sortedUsers,
                        isSharedMode,
                        currentUserName,
                        isShowcaseTarget: item.id == showcaseItemId,
                      ),
                    ),
                  );
                },
                childCount: items.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                addSemanticIndexes: false,
                findChildIndexCallback: (key) {
                  if (key is ValueKey<String>) {
                    return indexMap[key.value];
                  }
                  return null;
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _updateSearchQuery,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)?.inventorySearchHint ?? 'Search items...',
          hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.4), fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: colors.onSurface.withValues(alpha: 0.4)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear_rounded, color: colors.onSurface.withValues(alpha: 0.4), size: 20),
            onPressed: () {
              _searchController.clear();
              _updateSearchQuery('');
              FocusScope.of(context).unfocus();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.inventoryNoItemsFound ?? 'No items found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: FadeInSlide(
        index: 0,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Icon(Icons.inventory_2_outlined, size: 32, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)?.inventoryEmptyTitle ?? 'Your inventory is empty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.inventoryEmptySubtitle ?? 'Tap the + button to add items.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDismissibleItem(
      BuildContext context,
      FoodItem item,
      List<String> sortedUsers,
      bool isSharedMode,
      String currentUserName,
      {required bool isShowcaseTarget}
      ) {
    Widget card = _PressableScale(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryItemDetailPage(
              item: item,
              repo: widget.repo,
            ),
          ),
        );
      },
      onLongPress: () {
        AppHaptics.selection();
        _showItemActionsSheet(context, item, sortedUsers, isSharedMode);
      },
      child: _buildItemCard(context, item, isSharedMode, currentUserName),
    );

    if (isShowcaseTarget) {
      card = wrapWithShowcase(
        context: context,
        key: _longPressMenuKey,
        title: AppLocalizations.of(context)?.inventoryLongPressTitle ?? 'Long Press Menu',
        description: AppLocalizations.of(context)?.inventoryLongPressDescription ??
            'Press and hold an item to edit, use quantity, move, or delete.',
        child: card,
      );
    }

    Widget dismissible = Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
      ),
      onDismissed: (_) async {
        AppHaptics.success();
        final deletedItem = item;
        await widget.repo.deleteItem(item.id);
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context);
        _showToast(
          l10n?.inventoryDeletedToast(deletedItem.name) ?? 'Deleted "${deletedItem.name}"',
          onUndo: () async => widget.repo.addItem(deletedItem),
        );
      },
      child: card,
    );

    if (isShowcaseTarget) {
      dismissible = wrapWithShowcase(
        context: context,
        key: _swipeDeleteKey,
        title: AppLocalizations.of(context)?.inventorySwipeDeleteTitle ?? 'Swipe Left to Delete',
        description: AppLocalizations.of(context)?.inventorySwipeDeleteDescription ??
            'Swipe an item to the left to delete it. You can undo right after.',
        child: dismissible,
      );
    }

    return dismissible;
  }

  String? _resolveCategoryKey(FoodItem item) {
    return widget.repo.inferCategoryForName(item.name, existingCategory: item.category);
  }

  _CategoryOption? _categoryOptionForKey(String? key) {
    if (key == null) return null;
    for (final option in _categoryOptions) {
      if (option.key == key) return option;
    }
    return null;
  }

  Widget _categoryPill(_CategoryOption option) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: option.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(option.icon, size: 12, color: option.color),
          const SizedBox(width: 4),
          Text(
            option.label,
            style: TextStyle(
              fontSize: 11,
              color: option.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _categorySubtitle(FoodItem item) {
    final isAuto = !widget.repo.isExplicitCategory(item.category);
    final key = isAuto
        ? widget.repo.inferCategoryForName(item.name, existingCategory: item.category)
        : item.category?.trim().toLowerCase();
    final option = _categoryOptionForKey(key);
    if (option == null) {
      return isAuto ? 'Auto: Unknown' : 'Current: Unknown';
    }
    return isAuto ? 'Auto: ${option.label}' : 'Current: ${option.label}';
  }

  Future<String?> _pickCategory(BuildContext context, FoodItem item) {
    final inferred = widget.repo.inferCategoryForName(item.name, existingCategory: item.category);
    final raw = item.category?.trim().toLowerCase();
    final isAuto = !widget.repo.isExplicitCategory(item.category);
    final currentKey = isAuto ? inferred : raw;

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(
                  inferred == null ? 'Auto (Unknown)' : 'Auto (${_categoryOptionLabel(inferred)})',
                  style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
                ),
                trailing: (isAuto)
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.pop(ctx, _autoCategoryKey),
              ),
              const Divider(height: 1),
              ..._categoryOptions.map((option) {
                final selected = option.key == currentKey && !isAuto;
                return ListTile(
                  leading: Icon(option.icon, color: option.color),
                  title: Text(option.label, style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600)),
                  trailing: selected ? const Icon(Icons.check, size: 18) : null,
                  onTap: () => Navigator.pop(ctx, option.key),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _categoryOptionLabel(String? key) {
    final option = _categoryOptionForKey(key);
    return option?.label ?? 'Unknown';
  }

  Widget _buildItemCard(BuildContext context, FoodItem item, bool isSharedMode, String currentUserName) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final days = item.daysToExpiry;
    final qtyText = '${item.quantity.toStringAsFixed(2)} ${item.unit}';
    final categoryKey = _resolveCategoryKey(item);
    final categoryOption = _categoryOptionForKey(categoryKey);
    final daysLabel = days >= 999
        ? 'No Expiry'
        : days == 0
        ? 'Today'
        : days < 0
        ? '${-days}d ago'
        : '${days}d left';
    final urgency = _urgency(days);
    final urgencyColor = _urgencyColor(urgency, colors);
    final progressValue = _expiryProgressValue(days);

    Widget actionButton;
    if (item.location == StorageLocation.fridge) {
      actionButton = QuickActionButton(
        icon: Icons.ac_unit_rounded,
        color: Colors.lightBlueAccent,
        tooltip: "Freeze",
        onTap: () => _quickMoveItem(item, StorageLocation.freezer),
      );
    } else if (item.location == StorageLocation.freezer) {
      actionButton = QuickActionButton(
        icon: Icons.water_drop_rounded,
        color: Colors.orangeAccent,
        tooltip: "Defrost",
        iconWidget: _defrostIcon(Colors.orangeAccent),
        onTap: () => _quickMoveItem(item, StorageLocation.fridge),
      );
    } else {
      actionButton = const SizedBox(width: 32);
    }

    final leading = _leadingIcon(item);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.isLowStock ? Colors.orange.shade300 : theme.dividerColor,
              width: item.isLowStock ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 40,
                      decoration: BoxDecoration(
                        color: leading.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: _buildFoodIcon(
                        item,
                        size: 40,
                        imageSize: 48,
                        fallbackColor: leading.color,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                qtyText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurface.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (categoryOption != null) _categoryPill(categoryOption),
                              Text(
                                daysLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: urgencyColor,
                                ),
                              ),
                            ],
                          ),
                          if (item.note != null && item.note!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurface.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (item.location != StorageLocation.pantry) actionButton,
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 4,
                    backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(urgencyColor),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_fxItemId == item.id && _fxType != null && _fxController != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _fxController!,
                builder: (context, child) {
                  return _MoveEffectOverlay(
                    progress: _fxController!.value,
                    type: _fxType!,
                    borderRadius: BorderRadius.circular(20),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Color _urgencyColor(_Urgency urgency, ColorScheme colors) {
    switch (urgency) {
      case _Urgency.expired:
        return const Color(0xFFBA1A1A);
      case _Urgency.today:
        return const Color(0xFFBA1A1A);
      case _Urgency.soon:
        return const Color(0xFFFF9800);
      case _Urgency.ok:
        return const Color(0xFF2E7D32);
      case _Urgency.none:
        return colors.onSurface.withValues(alpha: 0.6);
    }
  }

  double _expiryProgressValue(int days) {
    if (days < 0) return 0.95;
    if (days == 0) return 0.9;
    if (days <= 2) return 0.8;
    if (days <= 5) return 0.6;
    if (days <= 10) return 0.4;
    return 0.25;
  }

  _Urgency _urgency(int days) {
    if (days < 0) return _Urgency.expired;
    if (days == 0) return _Urgency.today;
    if (days <= 3) return _Urgency.soon;
    if (days >= 999) return _Urgency.none;
    return _Urgency.ok;
  }

  Widget _defrostIcon(Color color) {
    final lineColor = Colors.white.withValues(alpha: 0.9);
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Icon(Icons.water_drop_rounded, color: color, size: 20),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Transform.rotate(
              angle: -0.7,
              alignment: Alignment.center,
              child: Container(
                width: 10,
                height: 1.6,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            right: 5,
            child: Transform.rotate(
              angle: 0.6,
              alignment: Alignment.center,
              child: Container(
                width: 8,
                height: 1.6,
                decoration: BoxDecoration(
                  color: lineColor.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _Leading _leadingIcon(FoodItem item) {
    switch (item.location) {
      case StorageLocation.fridge:
        return const _Leading(Icons.kitchen_rounded, Color(0xFF005F87));
      case StorageLocation.freezer:
        return const _Leading(Icons.ac_unit_rounded, Color(0xFF3F51B5));
      case StorageLocation.pantry:
        return const _Leading(Icons.shelves, Colors.brown);
    }
  }

  Widget _buildFoodIcon(
      FoodItem item, {
        required double size,
        double? imageSize,
        double fallbackScale = 0.55,
        Color? fallbackColor,
      }) {
    final assetPath = foodIconAssetForItem(item);
    final leading = _leadingIcon(item);
    final isDefaultIcon = assetPath.endsWith('/default.png');
    final resolvedSize = isDefaultIcon ? size * 0.55 : (imageSize ?? size);
    return Image.asset(
      assetPath,
      width: resolvedSize,
      height: resolvedSize,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(leading.icon, size: size * fallbackScale, color: fallbackColor ?? leading.color);
      },
    );
  }

  Future<void> _openEditPage(BuildContext context, FoodItem item) async {
    AppHaptics.selection();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddFoodPage(repo: widget.repo, itemToEdit: item)),
    );
  }

  Future<void> _editItemNote(BuildContext context, FoodItem item) async {
    final controller = TextEditingController(text: item.note ?? '');
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        AppLocalizations.of(context)?.inventoryItemNoteTitle ?? 'Item note',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)?.inventoryItemNoteHint ?? 'Add a short note...',
            hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.5)),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E2229) : const Color(0xFFF5F7FA),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.primary, width: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            child: Text(AppLocalizations.of(context)?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await widget.repo.updateItemNote(item, result);
    }
  }

  Future<void> _showItemActionsSheet(BuildContext context, FoodItem item, List<String> users, bool isSharedMode) async {
    final currentUserName = widget.repo.currentUserName;
    final ownerLabel = _resolveOwnerLabel(item.ownerName, currentUserName);
    final assignableUsers = users.where((u) => u != 'All' && u != 'Family').toList();

    final result = await showModalBottomSheet<_ConsumptionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ConsumptionSheet(
          item: item,
          initialAction: null,
          sortedUsers: assignableUsers,
          currentUserName: currentUserName,
          initialOwner: ownerLabel,
          showAssign: !isSharedMode,
          onEditFamily: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FamilyPage(repo: widget.repo)),
            );
          },
          onChangeCategory: () async {
            final picked = await _pickCategory(context, item);
            if (picked == null) return;
            final newCategory = picked == _autoCategoryKey ? null : picked;
            await widget.repo.updateItem(item.copyWith(category: newCategory));
            if (newCategory != null) {
              await widget.repo.rememberCategoryForName(item.name, newCategory);
            }
          },
        );
      },
    );

    if (result == null) return;

    final oldItem = item;
    final ownerChanged = result.assignedUser != null && result.assignedUser != ownerLabel && !isSharedMode;
    if (ownerChanged) {
      await _assignOwner(item, result.assignedUser!);
      AppHaptics.success();
    }

    if (result.action == null) {
      if (!context.mounted) return;
      if (ownerChanged) {
        _showToast('Updated assignment for ${item.name}');
      }
      return;
    }

    if (result.usedQty <= 0) return;
    await widget.repo.useItemWithImpact(item, result.action!, result.usedQty);
    AppHaptics.success();

    if (result.action == 'pet' && !widget.repo.hasShownPetWarning) {
      await widget.repo.markPetWarningShown();
      if (context.mounted) {
        _showToast(
          AppLocalizations.of(context)?.todayPetSafetyWarning ??
              'Please make sure the food is safe for your pet!',
        );
      }
    }

    if (!context.mounted) return;
    final verb = result.action == 'eat'
        ? 'Cooked'
        : (result.action == 'pet' ? 'Fed' : 'Wasted');
    _showToast(
      '$verb ${result.usedQty.toStringAsFixed(1)} ${item.unit} of ${item.name}',
      onUndo: () async => widget.repo.updateItem(oldItem),
    );
  }

  // ignore: unused_element
  Future<void> _showItemActionsSheetLegacy(BuildContext context, FoodItem item, List<String> users, bool isSharedMode) async {
    final currentUserName = widget.repo.currentUserName;
    final ownerLabel = _resolveOwnerLabel(item.ownerName, currentUserName);
    final assignableUsers = users.where((u) => u != 'All' && u != 'Family').toList();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.78),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _buildFoodIcon(item, size: 40, fallbackColor: _leadingIcon(item).color),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${item.quantity} ${item.unit}',
                                    style: TextStyle(
                                      color: colors.onSurface.withValues(alpha: 0.6),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: colors.onSurface.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.daysToExpiry < 0 ? 'Expired' : '${item.daysToExpiry} days left',
                                    style: TextStyle(
                                      color: item.daysToExpiry < 0
                                          ? Colors.red
                                          : (item.daysToExpiry <= 3 ? Colors.orange : Colors.green),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!isSharedMode) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text(
                        "Quick Assign",
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: assignableUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final user = assignableUsers[index];
                          final isSelected = ownerLabel == user;
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              if (!isSelected) _assignOwner(item, user);
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  children: [
                                    UserAvatarTag(
                                      name: user,
                                      size: 48,
                                      showBorder: isSelected,
                                      currentUserName: currentUserName,
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle),
                                          child: const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                        ),
                                      )
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  user == 'Family'
                                      ? (AppLocalizations.of(context)?.inventorySharedLabel ?? 'Shared')
                                      : user,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? colors.onSurface
                                        : colors.onSurface.withValues(alpha: 0.6),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(thickness: 1, height: 1, color: theme.dividerColor),
                    ),
                  ],

                  SheetTile(
                    icon: Icons.sticky_note_2_outlined,
                    title: (item.note != null && item.note!.trim().isNotEmpty)
                        ? (AppLocalizations.of(context)?.inventoryEditNote ?? 'Edit note')
                        : (AppLocalizations.of(context)?.inventoryAddNote ?? 'Add note'),
                    subtitle: AppLocalizations.of(context)?.inventoryNoteReminderSubtitle ?? 'Leave a quick reminder',
                    onTap: () {
                      Navigator.pop(ctx);
                      _editItemNote(context, item);
                    },
                  ),
                  SheetTile(
                    icon: Icons.category_outlined,
                    title: AppLocalizations.of(context)?.inventoryChangeCategory ?? 'Change category',
                    subtitle: _categorySubtitle(item),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final picked = await _pickCategory(context, item);
                      if (picked == null) return;
                      final newCategory = picked == _autoCategoryKey ? null : picked;
                      await widget.repo.updateItem(item.copyWith(category: newCategory));
                      if (newCategory != null) {
                        await widget.repo.rememberCategoryForName(item.name, newCategory);
                      }
                    },
                  ),

                  SheetTile(
                    icon: Icons.restaurant_menu_rounded,
                    title: AppLocalizations.of(context)?.inventoryCookWithThis ?? 'Cook with this',
                    subtitle: AppLocalizations.of(context)?.inventoryRecordUsageUpdateQty ?? 'Record usage & update quantity',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final oldItem = item;
                      // Pass users for the Quick Assign UI in the new dialog
                      final usedQty = await _askQuantityDialog(context, item, 'eat', users);
                      if (usedQty == null || usedQty <= 0) return;
                      await widget.repo.useItemWithImpact(item, 'eat', usedQty);
                      if (!context.mounted) return;
                      final l10n = AppLocalizations.of(context);
                      _showToast(
                        l10n?.inventoryCookedToast(usedQty.toStringAsFixed(1), item.name) ??
                            'Cooked ${usedQty.toStringAsFixed(1)} of ${item.name}',
                        onUndo: () async => widget.repo.updateItem(oldItem),
                      );
                    },
                  ),
                  SheetTile(
                    icon: Icons.pets_rounded,
                    title: AppLocalizations.of(context)?.inventoryFeedToPet ?? 'Feed to pet',
                    subtitle: AppLocalizations.of(context)?.inventoryGreatForLeftovers ?? 'Great for leftovers',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final oldItem = item;
                      final usedQty = await _askQuantityDialog(context, item, 'pet', users);
                      if (usedQty == null || usedQty <= 0) return;

                      await widget.repo.useItemWithImpact(item, 'pet', usedQty);

                      if (!widget.repo.hasShownPetWarning) {
                        await widget.repo.markPetWarningShown();
                        if (!context.mounted) return;
                        _showToast(
                          AppLocalizations.of(context)?.todayPetSafetyWarning ??
                              'Please make sure the food is safe for your pet!',
                        );
                      }

                      if (!context.mounted) return;
                      final l10n = AppLocalizations.of(context);
                      _showToast(
                        l10n?.inventoryFedToPetToast(item.name) ?? 'Fed ${item.name} to pet',
                        onUndo: () async => widget.repo.updateItem(oldItem),
                      );
                    },
                  ),

                  SheetTile(
                    icon: Icons.delete_sweep_rounded,
                    title: AppLocalizations.of(context)?.inventoryWastedThrownAway ?? 'Wasted / Thrown away',
                    subtitle: AppLocalizations.of(context)?.inventoryTrackWasteImproveHabits ?? 'Track waste to improve habits',
                    iconColor: Colors.deepOrange, // NOTE: legacy comment cleaned.
                    onTap: () async {
                      Navigator.pop(ctx);
                      final oldItem = item;
                      final usedQty = await _askQuantityDialog(context, item, 'trash', users);
                      if (usedQty == null || usedQty <= 0) return;

                      await widget.repo.useItemWithImpact(item, 'trash', usedQty);

                      if (!context.mounted) return;
                      final l10n = AppLocalizations.of(context);
                      _showToast(
                        l10n?.inventoryRecordedWasteToast(item.name) ?? 'Recorded waste: ${item.name}',
                        onUndo: () async => widget.repo.updateItem(oldItem),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(thickness: 1, height: 1, color: theme.dividerColor),
                  ),
                  SheetTile(
                    icon: Icons.edit_rounded,
                    title: AppLocalizations.of(context)?.inventoryEditDetails ?? 'Edit details',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openEditPage(context, item);
                    },
                  ),
                  SheetTile(
                    icon: Icons.delete_outline_rounded,
                    title: AppLocalizations.of(context)?.inventoryDeleteItem ?? 'Delete item',
                    danger: true,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await _confirmDelete(context, item);
                      if (!ok) return;

                      final deletedItem = item;
                      await widget.repo.deleteItem(item.id);
                      if (!context.mounted) return;
                      final l10n = AppLocalizations.of(context);
                      _showToast(
                        l10n?.inventoryDeletedToast(deletedItem.name) ?? 'Deleted "${deletedItem.name}"',
                        onUndo: () async => widget.repo.addItem(deletedItem),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Refactored to match the "Unified Consumption Hub" design
  Future<double?> _askQuantityDialog(
      BuildContext context,
      FoodItem item,
      String action,
      List<String> sortedUsers,
      ) async {
    final ownerLabel = _resolveOwnerLabel(item.ownerName, widget.repo.currentUserName);
    final result = await showModalBottomSheet<_ConsumptionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConsumptionSheet(
        item: item,
        initialAction: action,
        sortedUsers: sortedUsers,
        currentUserName: widget.repo.currentUserName,
        initialOwner: ownerLabel,
        showAssign: true,
        onEditFamily: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FamilyPage(repo: widget.repo)),
          );
        },
      ),
    );
    return result?.usedQty;
  }

  Future<bool> _confirmDelete(BuildContext context, FoodItem item) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            AppLocalizations.of(context)?.inventoryDeleteItemQuestion ?? 'Delete item?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            AppLocalizations.of(context)?.inventoryDeletePermanentQuestion(item.name) ??
                'Remove "${item.name}" from your inventory permanently?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancel',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(
                AppLocalizations.of(context)?.inventoryDeleteAction ?? 'Delete',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    ) ??
        false;
  }
}

// -----------------------------------------------------------------------------
// NEW: Consumption Sheet Component (Matches HTML Design)
// -----------------------------------------------------------------------------

class _ConsumptionResult {
  final double usedQty;
  final String? action; // eat | pet | trash
  final String? assignedUser;

  const _ConsumptionResult({
    required this.usedQty,
    required this.action,
    required this.assignedUser,
  });
}

class _ConsumptionSheet extends StatefulWidget {
  final FoodItem item;
  final String? initialAction;
  final List<String> sortedUsers;
  final String currentUserName;
  final String? initialOwner;
  final bool showAssign;
  final VoidCallback? onEditFamily;
  final VoidCallback? onChangeCategory;

  const _ConsumptionSheet({
    required this.item,
    required this.initialAction,
    required this.sortedUsers,
    required this.currentUserName,
    required this.initialOwner,
    required this.showAssign,
    this.onEditFamily,
    this.onChangeCategory,
  });

  @override
  State<_ConsumptionSheet> createState() => _ConsumptionSheetState();
}

class _ConsumptionSheetState extends State<_ConsumptionSheet>
    with SingleTickerProviderStateMixin {
  // Constants from design
  static const Color _bgDark = Color(0xFF101622);
  static const Color _primaryBlue = Color(0xFF1B78FF);
  static const Color _emerald = Color(0xFF10B981); // Emerald 500
  static const Color _purple = Color(0xFFA855F7); // Purple 500
  static const Color _red = Color(0xFFEF4444); // Red 500

  late double _quantityUsed;
  String? _selectedAction;
  String? _selectedOwner;
  late final AnimationController _breathController;
  bool _isSliding = false;
  double? _lastSnapFraction;
  static const List<double> _snapFractions = [0.0, 0.25, 0.5, 0.75, 1.0];

  @override
  void initState() {
    super.initState();
    // Default to 50% or full if small quantity
    _quantityUsed = 0;
    _selectedAction = widget.initialAction;
    _selectedOwner = widget.initialOwner;
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  String get _percentString {
    if (widget.item.quantity == 0) return '0%';
    final pct = (_quantityUsed / widget.item.quantity * 100).round();
    return '$pct';
  }

  String get _remainingString {
    final rem = widget.item.quantity - _quantityUsed;
    return rem.toStringAsFixed(1);
  }

  double _snapQuantityIfNeeded(double value) {
    final max = widget.item.quantity;
    if (max <= 0) return 0;
    final fraction = (value / max).clamp(0.0, 1.0);

    double nearest = _snapFractions.first;
    var nearestDelta = (fraction - nearest).abs();
    for (final f in _snapFractions.skip(1)) {
      final d = (fraction - f).abs();
      if (d < nearestDelta) {
        nearest = f;
        nearestDelta = d;
      }
    }

    if (nearestDelta <= 0.035) {
      if (_lastSnapFraction != nearest) {
        _lastSnapFraction = nearest;
        AppHaptics.selection();
      }
      return (nearest * max).clamp(0.0, max);
    }

    _lastSnapFraction = null;
    return value.clamp(0.0, max);
  }

  // Use the "Sticky Button Overlay" version of the build method and remove the duplicate
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? _bgDark : theme.scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final mutedText = isDark ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final subtleText = isDark ? Colors.white54 : theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final handleColor = isDark ? Colors.white24 : theme.dividerColor.withValues(alpha: 0.6);
    final buttonEnabled = (_selectedAction != null && _quantityUsed > 0) ||
        (_selectedOwner != null && _selectedOwner != widget.initialOwner);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40)],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 8),
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.item.name,
                              style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                  l10n?.inventorySheetUpdating(widget.item.name) ??
                                      'Updating: ${widget.item.name}',
                                  style: TextStyle(color: subtleText, fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 8),
                              _ChangeChip(onTap: widget.onChangeCategory),
                            ],
                          ),
                        ],
                      ),
                      _CloseButton(onTap: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildSliderSection(),
                      const SizedBox(height: 24),
                      Text(l10n?.inventoryActionType ?? 'ACTION TYPE',
                          style: TextStyle(color: mutedText, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _ActionCard(
                                  icon: Icons.soup_kitchen,
                                  label: l10n?.inventoryActionCooked ?? 'Cooked',
                                  color: _emerald,
                                  isSelected: _selectedAction == 'eat',
                                  onTap: () => setState(() => _selectedAction = _selectedAction == 'eat' ? null : 'eat'))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _ActionCard(
                                  icon: Icons.pets,
                                  label: l10n?.inventoryActionPetFeed ?? 'Pet Feed',
                                  color: _purple,
                                  isSelected: _selectedAction == 'pet',
                                  onTap: () => setState(() => _selectedAction = _selectedAction == 'pet' ? null : 'pet'))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _ActionCard(
                                  icon: Icons.delete_outline,
                                  label: l10n?.inventoryActionWaste ?? 'Waste',
                                  color: _red,
                                  isSelected: _selectedAction == 'trash',
                                  onTap: () => setState(() => _selectedAction = _selectedAction == 'trash' ? null : 'trash'))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (widget.showAssign) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n?.inventoryQuickAssign ?? 'QUICK ASSIGN',
                                style: TextStyle(color: mutedText, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                            TextButton(
                              onPressed: widget.onEditFamily,
                              child: Text(
                                l10n?.inventoryEditFamily ?? 'EDIT FAMILY',
                                style: TextStyle(color: _primaryBlue.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.sortedUsers.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              if (index == widget.sortedUsers.length) {
                                return _AddUserButton(onTap: widget.onEditFamily);
                              }
                              final user = widget.sortedUsers[index];
                              final isSelected = _selectedOwner == user;
                              return _FamilyAvatar(
                                name: user == widget.currentUserName
                                    ? (l10n?.inventoryYouLabel ?? 'You')
                                    : user,
                                isSelected: isSelected,
                                onTap: () => setState(() => _selectedOwner = user),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 120), // Bottom padding for button
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Opacity(
                opacity: buttonEnabled ? 1.0 : 0.5,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [_primaryBlue, Color(0xFF2563EB)]),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: buttonEnabled
                          ? () {
                        AppHaptics.success();
                        Navigator.pop(
                          context,
                          _ConsumptionResult(
                            usedQty: _selectedAction == null ? 0 : _quantityUsed,
                            action: _selectedAction,
                            assignedUser: _selectedOwner,
                          ),
                        );
                      }
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            l10n?.inventoryConfirmUpdate ?? 'Confirm Update',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSection() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final subtle = isDark ? Colors.white.withValues(alpha: 0.3) : theme.colorScheme.onSurface.withValues(alpha: 0.35);
    final trackBackground = isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerHighest;
    final trackBorder = isDark ? Colors.white10 : theme.dividerColor.withValues(alpha: 0.6);
    final thumbColor = isDark ? Colors.white : theme.colorScheme.surface;
    final progress = widget.item.quantity == 0
        ? 0.0
        : (_quantityUsed / widget.item.quantity).clamp(0.0, 1.0);
    final breathValue = _isSliding ? 0.0 : _breathController.value;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n?.inventoryQuantityUsed ?? 'Quantity Used',
              style: TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: _percentString,
                    style: const TextStyle(
                      color: _primaryBlue,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  TextSpan(
                    text: '%',
                    style: TextStyle(
                      color: _primaryBlue.withValues(alpha: 0.7),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 36,
              activeTrackColor: Colors.transparent, // Handled by container
              inactiveTrackColor: Colors.transparent, // Handled by container
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: _isSliding ? 17 : 15,
                elevation: _isSliding ? 7 : 4,
              ),
              overlayShape: RoundSliderOverlayShape(
                overlayRadius: _isSliding ? 28 : 22,
              ),
              thumbColor: thumbColor,
              overlayColor: _primaryBlue.withValues(alpha: _isSliding ? 0.24 : 0.14),
            ),
            child: Stack(
              children: [
                // Track Background
                AnimatedBuilder(
                  animation: _breathController,
                  builder: (context, child) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final fillWidth = constraints.maxWidth * progress;
                        final pulseBoost = 0.18 * breathValue;
                        return Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: trackBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: trackBorder),
                          ),
                          child: Stack(
                            children: [
                              AnimatedContainer(
                                duration: Duration(milliseconds: _isSliding ? 90 : 220),
                                curve: _isSliding ? Curves.linear : Curves.easeOutCubic,
                                width: fillWidth,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF2563EB),
                                      Color.lerp(_primaryBlue, Colors.white, pulseBoost)!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: progress > 0
                                      ? [
                                          BoxShadow(
                                            color: _primaryBlue.withValues(alpha: _isSliding ? 0.38 : (0.22 + pulseBoost)),
                                            blurRadius: _isSliding ? 14 : (10 + 8 * breathValue),
                                            spreadRadius: _isSliding ? 1 : (0.5 + breathValue),
                                          ),
                                        ]
                                      : [],
                                ),
                              ),
                              if (progress > 0)
                                Positioned(
                                  left: (fillWidth - 2).clamp(0.0, constraints.maxWidth - 2),
                                  top: 6,
                                  bottom: 6,
                                  child: Container(width: 2, color: subtle),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                // The actual slider on top
                Semantics(
                  label: l10n?.inventorySemanticsQuantityUsed ?? 'Quantity used',
                  value: '$_percentString percent',
                  hint: l10n?.inventorySemanticsUsageHint ?? 'Drag left or right to adjust usage',
                  child: Tooltip(
                    message: l10n?.inventorySemanticsAdjustUsedAmount ?? 'Adjust used amount',
                    child: Slider(
                      value: _quantityUsed,
                      min: 0,
                      max: widget.item.quantity,
                      onChangeStart: (_) => setState(() {
                        _isSliding = true;
                        _lastSnapFraction = null;
                      }),
                      onChanged: (val) => setState(() => _quantityUsed = _snapQuantityIfNeeded(val)),
                      onChangeEnd: (_) {
                        setState(() => _isSliding = false);
                        AppHaptics.selection();
                      },
                      // Custom thumb handling visually
                      thumbColor: thumbColor,
                    ),
                  ),
                ),
                // Center Icon on Thumb (Visual Hack - ideally use custom thumb shape)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment(
                        -1.0 + (progress * 2.0).clamp(0.0, 2.0),
                        0.0
                    ),
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 12), // Adjust for thumb radius
                      child: const Icon(Icons.unfold_more, color: _primaryBlue, size: 16),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%', style: TextStyle(color: subtle, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(
                (l10n?.inventoryRemainingQty(_remainingString, widget.item.unit) ??
                        'Remaining: $_remainingString${widget.item.unit}')
                    .toUpperCase(),
                style: TextStyle(color: subtle, fontSize: 10, fontWeight: FontWeight.bold)),
            Text('100%', style: TextStyle(color: subtle, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseText = isDark ? Colors.white54 : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final baseFill = isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerHighest;
    final baseBorder = isDark ? Colors.white.withValues(alpha: 0.1) : theme.dividerColor.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : baseFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.4) : baseBorder,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: isSelected ? color : baseText, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? color.withValues(alpha: 0.9) : baseText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  final VoidCallback? onTap;
  const _ChangeChip({this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerHighest;
    final border = isDark ? Colors.white10 : theme.dividerColor.withValues(alpha: 0.6);
    final textColor = isDark ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            const Icon(Icons.category, size: 12, color: Color(0xFF135bec)),
            const SizedBox(width: 4),
            Text(
              'CHANGE',
              style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerHighest;
    final iconColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.close, color: iconColor, size: 20),
      ),
    );
  }
}

class _FamilyAvatar extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _FamilyAvatar({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF135bec);
    final labelColor = isDark ? Colors.white54 : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final avatarFill = isDark ? Colors.grey[800] : theme.colorScheme.surfaceContainerHighest;
    final avatarText = isDark ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final checkBorder = isDark ? _ConsumptionSheetState._bgDark : theme.scaffoldBackgroundColor;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? primaryBlue : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: primaryBlue.withValues(alpha: 0.4), blurRadius: 10)]
                      : [],
                ),
                child: Container(
                  alignment: Alignment.center,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarFill,
                  ),
                  child: Text(
                    name.isNotEmpty ? name.trim()[0].toUpperCase() : '?',
                    style: TextStyle(color: avatarText, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: checkBorder, width: 2),
                    ),
                    child: const Icon(Icons.check, size: 10, color: Colors.white),
                  ),
                )
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name.toUpperCase(),
          style: TextStyle(
            color: isSelected ? primaryBlue : labelColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        )
      ],
    );
  }
}

class _AddUserButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddUserButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white30 : theme.dividerColor.withValues(alpha: 0.7);
    final iconColor = isDark ? Colors.white54 : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final textColor = isDark ? Colors.white54 : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, style: BorderStyle.solid),
              color: Colors.transparent,
            ),
            child: Icon(Icons.add, color: iconColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ADD',
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// NOTE: legacy comment cleaned.
class SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  final Color? iconColor;

  const SheetTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.danger = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: danger ? Colors.red.withValues(alpha: 0.1) : colors.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        // NOTE: legacy comment cleaned.
        child: Icon(
            icon,
            color: iconColor ?? (danger ? Colors.red : colors.onSurface.withValues(alpha: 0.7)),
            size: 24
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: danger ? Colors.red : colors.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle!,
        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
      )
          : null,
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _PressableScale({
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _setPressed(true);
        AppHaptics.selection();
      },
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap?.call();
      },
      onTapCancel: () => _setPressed(false),
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _CategoryOption {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const _CategoryOption(this.key, this.label, this.icon, this.color);
}






