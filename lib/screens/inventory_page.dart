// lib/screens/inventory_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import 'add_food_page.dart';
import '../widgets/animations.dart'; 
import '../widgets/inventory_components.dart'; // 假设 QuickActionButton, UserAvatarTag 等在这里

typedef AppSnackBarFn = void Function(String message, {VoidCallback? onUndo});

enum _Urgency { expired, today, soon, ok, none }

class _Leading {
  final IconData icon;
  final Color color;
  const _Leading(this.icon, this.color);
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

  const InventoryPageWrapper({
    super.key,
    required this.repo,
    required this.onRefresh,
    required this.showSnackBar,
  });

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => InventoryPage(
        repo: repo,
        onRefresh: onRefresh,
        showSnackBar: showSnackBar,
      ),
    );
  }
}

class InventoryPage extends StatefulWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;
  final AppSnackBarFn showSnackBar;

  const InventoryPage({
    super.key,
    required this.repo,
    required this.onRefresh,
    required this.showSnackBar,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey _searchKey = GlobalKey();

  String _selectedUser = 'All';
  _InventoryViewData _viewData = _InventoryViewData.empty();

  final Map<StorageLocation, bool> _sectionExpanded = {
    StorageLocation.fridge: true,
    StorageLocation.freezer: true,
    StorageLocation.pantry: true,
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _viewData = _computeViewData();
    widget.repo.addListener(_onRepoChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowTutorial());
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasShown = prefs.getBool('hasShownIntro_v6') ?? false;
    if (!hasShown) {
      try {
        ShowCaseWidget.of(context).startShowCase([_searchKey]);
        await prefs.setBool('hasShownIntro_v6', true);
      } catch (e) {
        debugPrint("Showcase error: $e");
      }
    }
  }

  Future<void> _checkAndShowGestureHint(bool hasItems) async {
    if (!hasItems) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasShownHint = prefs.getBool('hasShownGestureHint_v3') ?? false;
    if (!hasShownHint) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _showToast('💡 Tip: Tap the Snowflake/Fire icon to move items fast!');
          prefs.setBool('hasShownGestureHint_v3', true);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _showToast(String message, {VoidCallback? onUndo}) {
    widget.showSnackBar(message, onUndo: onUndo);
  }

  void _onRepoChanged() {
    if (!mounted) return;
    setState(() => _viewData = _computeViewData());
  }

  void _updateSearchQuery(String value) {
    setState(() {
      _searchQuery = value;
      _viewData = _computeViewData();
    });
  }

  void _setSelectedUser(String user) {
    setState(() {
      _selectedUser = user;
      _viewData = _computeViewData();
    });
  }

  _InventoryViewData _computeViewData() {
    final allItems = widget.repo.getActiveItems();
    final isSharedMode = widget.repo.isSharedUsage;
    final currentUserName = widget.repo.currentUserName;

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

    var filteredList = allItems;
    if (_searchQuery.isNotEmpty) {
      filteredList = filteredList
          .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    var resolvedUser = _selectedUser;
    if (!isSharedMode && resolvedUser != 'All') {
      if (resolvedUser == 'Family' || resolvedUser == 'Shared') {
        resolvedUser = currentUserName;
      }
      if (resolvedUser == 'Me') {
        resolvedUser = currentUserName;
      }
      filteredList = filteredList.where((i) {
        final owner = _resolveOwnerLabel(i.ownerName, currentUserName);
        return owner == resolvedUser;
      }).toList();
    } else if (!isSharedMode) {
      filteredList = filteredList.where((i) => i.ownerName != 'Family').toList();
    }

    if (resolvedUser != _selectedUser) {
      _selectedUser = resolvedUser;
    }

    filteredList.sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));

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
    HapticFeedback.mediumImpact();
    final oldLocation = item.location;

    await widget.repo.updateItem(item.copyWith(location: target));
    if (!mounted) return;

    final action = target == StorageLocation.freezer ? "Frozen" : "Defrosted";
    _showToast(
      '$action "${item.name}" ❄️➡️🔥',
      onUndo: () => widget.repo.updateItem(item.copyWith(location: oldLocation)),
    );
  }

  Future<void> _assignOwner(FoodItem item, String newOwnerName) async {
    HapticFeedback.mediumImpact();
    await widget.repo.assignItemToUser(item.id, newOwnerName);
    if (!mounted) return;
    _showToast("Assigned to $newOwnerName ✅");
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

    if (hasAnyItems && !isSearching) {
      _checkAndShowGestureHint(true);
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Inventory',
            style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface, fontSize: 24),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        ),
      body: !hasAnyItems
          ? _buildEmptyState(context)
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Showcase(
                          key: _searchKey,
                          title: 'Quick Search',
                          description: 'Find items instantly.',
                          targetBorderRadius: BorderRadius.circular(16),
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
                            itemBuilder: (context, index) {
                              final user = sortedUsers[index];
                              final isSelected = _selectedUser == user;
                              return UserFilterChip(
                                label: user,
                                isSelected: isSelected,
                                onTap: () {
                                  HapticFeedback.selectionClick();
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
                    title: 'Fridge',
                    icon: Icons.kitchen_rounded,
                    color: const Color(0xFF005F87),
                    items: fridgeItems,
                    location: StorageLocation.fridge,
                    sortedUsers: sortedUsers,
                    isSharedMode: isSharedMode,
                    currentUserName: currentUserName,
                  ),

                if (freezerItems.isNotEmpty)
                  _buildSliverSection(
                    title: 'Freezer',
                    icon: Icons.ac_unit_rounded,
                    color: const Color(0xFF3F51B5),
                    items: freezerItems,
                    location: StorageLocation.freezer,
                    sortedUsers: sortedUsers,
                    isSharedMode: isSharedMode,
                    currentUserName: currentUserName,
                  ),

                if (pantryItems.isNotEmpty)
                  _buildSliverSection(
                    title: 'Pantry',
                    icon: Icons.shelves,
                    color: Colors.brown,
                    items: pantryItems,
                    location: StorageLocation.pantry,
                    sortedUsers: sortedUsers,
                    isSharedMode: isSharedMode,
                    currentUserName: currentUserName,
                  ),
                
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isExpanded = _sectionExpanded[location] ?? true;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _sectionExpanded[location] = !isExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface.withOpacity(0.65),
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.onSurface.withOpacity(0.45),
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
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildDismissibleItem(
                        context,
                        item,
                        sortedUsers,
                        isSharedMode,
                        currentUserName,
                      ),
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _updateSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey[400], size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _updateSearchQuery('');
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              'No items found',
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
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Icon(Icons.inventory_2_outlined, size: 32, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
              Text(
                'Your inventory is empty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to add items.',
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
  ) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
      ),
      onDismissed: (_) async {
        HapticFeedback.mediumImpact();
        final deletedItem = item;
        await widget.repo.deleteItem(item.id);
        if (!context.mounted) return;
        _showToast(
          'Deleted "${deletedItem.name}"',
          onUndo: () async => widget.repo.addItem(deletedItem),
        );
      },
      child: BouncingButton(
        onTap: () => _openEditPage(context, item),
        onLongPress: () {
          HapticFeedback.selectionClick();
          _showItemActionsSheet(context, item, sortedUsers, isSharedMode);
        },
        child: _buildItemCard(context, item, isSharedMode, currentUserName),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, FoodItem item, bool isSharedMode, String currentUserName) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final days = item.daysToExpiry;
    final ownerLabel = _resolveOwnerLabel(item.ownerName, currentUserName);
    final qtyText = '${item.quantity.toStringAsFixed(2)} ${item.unit}';
    final categoryLabel = item.category?.trim();
    final hasCategory = categoryLabel != null && categoryLabel.isNotEmpty;
    final daysLabel = days >= 999
        ? 'No Expiry'
        : days == 0
            ? 'Today'
            : days < 0
                ? '${-days}d ago'
                : '${days}d left';
    final urgency = _urgency(days);

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
        onTap: () => _quickMoveItem(item, StorageLocation.fridge),
      );
    } else {
      actionButton = const SizedBox(width: 32);
    }

    final leading = _leadingIcon(item);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isLowStock ? Colors.orange.shade300 : theme.dividerColor,
          width: item.isLowStock ? 1.2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            if (!isSharedMode) ...[
              UserAvatarTag(
                name: ownerLabel,
                size: 34,
                showBorder: true,
                currentUserName: currentUserName,
              ),
              const SizedBox(width: 12),
            ],
            if (isSharedMode) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: leading.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(leading.icon, size: 16, color: leading.color),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        qtyText,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withOpacity(0.65),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasCategory) ...[
                        const SizedBox(width: 6),
                        _metaDot(context),
                        const SizedBox(width: 6),
                        Text(
                          categoryLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      _metaDot(context),
                      const SizedBox(width: 6),
                      _expiryPill(context, urgency, daysLabel),
                    ],
                  ),
                ],
              ),
            ),
            if (item.location != StorageLocation.pantry) actionButton,
          ],
        ),
      ),
    );
  }

  _Urgency _urgency(int days) {
    if (days < 0) return _Urgency.expired;
    if (days == 0) return _Urgency.today;
    if (days <= 3) return _Urgency.soon;
    if (days >= 999) return _Urgency.none;
    return _Urgency.ok;
  }

  Widget _expiryPill(BuildContext context, _Urgency u, String text) {
    Color fg;
    switch (u) {
      case _Urgency.expired:
        fg = const Color(0xFFD32F2F);
        break;
      case _Urgency.today:
        fg = const Color(0xFFE65100);
        break;
      case _Urgency.soon:
        fg = const Color(0xFFF57F17);
        break;
      case _Urgency.ok:
        fg = const Color(0xFF2E7D32);
        break;
      case _Urgency.none:
        fg = const Color(0xFF616161);
        break;
    }
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg));
  }

  Widget _metaDot(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: colors.onSurface.withOpacity(0.35),
        shape: BoxShape.circle,
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

  Future<void> _openEditPage(BuildContext context, FoodItem item) async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddFoodPage(repo: widget.repo, itemToEdit: item)),
    );
  }

  Future<void> _showItemActionsSheet(BuildContext context, FoodItem item, List<String> users, bool isSharedMode) async {
    final currentUserName = widget.repo.currentUserName;
    final ownerLabel = _resolveOwnerLabel(item.ownerName, currentUserName);
    final assignableUsers = users.where((u) => u != 'All' && u != 'Family').toList();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
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
                          color: colors.onSurface.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(_leadingIcon(item).icon, size: 28, color: _leadingIcon(item).color),
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
                                    color: colors.onSurface.withOpacity(0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: colors.onSurface.withOpacity(0.3),
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
                        color: colors.onSurface.withOpacity(0.6),
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
                                user == 'Family' ? 'Shared' : user,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? colors.onSurface
                                      : colors.onSurface.withOpacity(0.6),
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
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Cook with this',
                  subtitle: 'Record usage & update quantity',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final oldItem = item;
                    final usedQty = await _askQuantityDialog(context, item, 'eat');
                    if (usedQty == null || usedQty <= 0) return;
                    await widget.repo.useItemWithImpact(item, 'eat', usedQty);
                    if (!context.mounted) return;
                    _showToast(
                      'Cooked ${usedQty.toStringAsFixed(1)} of ${item.name}',
                      onUndo: () async => widget.repo.updateItem(oldItem),
                    );
                  },
                ),
                SheetTile(
                  icon: Icons.pets_rounded,
                  title: 'Feed to pet',
                  subtitle: 'Great for leftovers',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final oldItem = item;
                    final usedQty = await _askQuantityDialog(context, item, 'pet');
                    if (usedQty == null || usedQty <= 0) return;

                    await widget.repo.useItemWithImpact(item, 'pet', usedQty);

                    if (!widget.repo.hasShownPetWarning) {
                      await widget.repo.markPetWarningShown();
                      if (!context.mounted) return;
                      _showToast('Please make sure the food is safe for your pet!');
                    }

                    if (!context.mounted) return;
                    _showToast(
                      'Fed ${item.name} to pet',
                      onUndo: () async => widget.repo.updateItem(oldItem),
                    );
                  },
                ),

                // 🟢 🟢 新增：Waste / Trash 选项 🟢 🟢
                SheetTile(
                  icon: Icons.delete_sweep_rounded,
                  title: 'Wasted / Thrown away',
                  subtitle: 'Track waste to improve habits',
                  iconColor: Colors.deepOrange, // 红色图标
                  onTap: () async {
                    Navigator.pop(ctx);
                    final oldItem = item;
                    // 传入 'trash' 动作
                    final usedQty = await _askQuantityDialog(context, item, 'trash');
                    if (usedQty == null || usedQty <= 0) return;

                    await widget.repo.useItemWithImpact(item, 'trash', usedQty);

                    if (!context.mounted) return;
                    _showToast(
                      'Recorded waste: ${item.name}',
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
                  title: 'Edit details',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEditPage(context, item);
                  },
                ),
                SheetTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete item',
                  danger: true,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _confirmDelete(context, item);
                    if (!ok) return;

                    final deletedItem = item;
                    await widget.repo.deleteItem(item.id);
                    if (!context.mounted) return;
                    _showToast(
                      'Deleted "${deletedItem.name}"',
                      onUndo: () async => widget.repo.addItem(deletedItem),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<double?> _askQuantityDialog(BuildContext context, FoodItem item, String action) async {
    final controller = TextEditingController(
      text: item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1),
    );
    // 🟢 动态标题
    String title;
    if (action == 'eat') {
      title = 'How much did you cook?';
    } else if (action == 'pet') {
      title = 'How much did you feed?';
    } else {
      title = 'How much was wasted?';
    }

    String? selectedChip = 'All';
    String? errorText;

    return showDialog<double>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateQty(double val, String chipLabel) {
              controller.text = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2);
              setState(() {
                selectedChip = chipLabel;
                errorText = null;
              });
            }

            Widget buildChip(String label, double val) {
              final isSelected = selectedChip == label;
              return ActionChip(
                label: Text(label),
                onPressed: () => updateQty(val, label),
                backgroundColor: isSelected ? const Color(0xFF005F87).withOpacity(0.15) : Colors.grey[100],
                side: BorderSide(color: isSelected ? const Color(0xFF005F87) : Colors.transparent, width: 1.5),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF005F87) : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 12,
                ),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Available: ${item.quantity.toStringAsFixed(1)} ${item.unit}',
                          style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    buildChip('All', item.quantity),
                    buildChip('½', item.quantity / 2),
                    buildChip('¼', item.quantity / 4),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Quantity used',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: Colors.white,
                      errorText: errorText,
                    ),
                    onTap: () {
                      if (selectedChip != null) setState(() => selectedChip = null);
                    },
                    onChanged: (_) {
                      if (selectedChip != null) setState(() => selectedChip = null);
                      if (errorText != null) setState(() => errorText = null);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                FilledButton(
                  onPressed: () {
                    final raw = double.tryParse(controller.text.replaceAll(',', '.')) ?? double.nan;
                    if (raw.isNaN) {
                      setState(() => errorText = 'Enter a valid number');
                      return;
                    }
                    if (raw <= 0) {
                      setState(() => errorText = 'Quantity must be > 0');
                      return;
                    }
                    if (raw > item.quantity + 1e-9) {
                      setState(() => errorText = 'Max available: ${item.quantity}');
                      return;
                    }
                    Navigator.pop(ctx, raw);
                  },
                  child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, FoodItem item) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: const Text('Delete item?', style: TextStyle(fontWeight: FontWeight.w700)),
              content: Text('Remove "${item.name}" from your inventory permanently?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

// 🟢 附带：升级版的 SheetTile 组件 (支持 iconColor)
// 如果你已经在 inventory_components.dart 里定义了它，请更新那个文件；
// 或者直接保留在下方，但注意不要重复定义。
class SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  final Color? iconColor; // 新增

  const SheetTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.danger = false,
    this.iconColor, // 新增
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: danger ? Colors.red.withOpacity(0.1) : colors.onSurface.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        // 优先使用 iconColor，其次根据 danger 判断
        child: Icon(
          icon, 
          color: iconColor ?? (danger ? Colors.red : colors.onSurface.withOpacity(0.7)), 
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
              style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6)),
            )
          : null,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
