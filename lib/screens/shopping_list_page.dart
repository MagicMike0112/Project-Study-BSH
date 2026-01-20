// lib/screens/shopping_list_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:uuid/uuid.dart';

import '../repositories/inventory_repository.dart';
import '../widgets/add_by_recipe_sheet.dart'; 
import 'fridge_camera_page.dart';
import 'shopping_archive_page.dart';

class ShoppingListPageWrapper extends StatefulWidget {
  final InventoryRepository repo;

  const ShoppingListPageWrapper({super.key, required this.repo});

  @override
  State<ShoppingListPageWrapper> createState() => _ShoppingListPageWrapperState();
}

class _ShoppingListPageWrapperState extends State<ShoppingListPageWrapper> {
  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _aiKey = GlobalKey();
  final GlobalKey _fridgeKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();
  bool _didShow = false;

  Future<void> _maybeShowTutorial(BuildContext context) async {
    if (_didShow) return;
    _didShow = true;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasShown = prefs.getBool('hasShownIntro_shopping_v1') ?? false;
    if (!hasShown) {
      try {
        ShowCaseWidget.of(context).startShowCase([_addKey, _aiKey, _fridgeKey, _historyKey]);
        await prefs.setBool('hasShownIntro_shopping_v1', true);
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
        return ShoppingListPage(
          repo: widget.repo,
          addKey: _addKey,
          aiKey: _aiKey,
          fridgeKey: _fridgeKey,
          historyKey: _historyKey,
        );
      },
    );
  }
}

class ShoppingListPage extends StatefulWidget {
  final InventoryRepository repo;
  final GlobalKey? addKey;
  final GlobalKey? aiKey;
  final GlobalKey? fridgeKey;
  final GlobalKey? historyKey;

  const ShoppingListPage({
    super.key,
    required this.repo,
    this.addKey,
    this.aiKey,
    this.fridgeKey,
    this.historyKey,
  });

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final TextEditingController _controller = TextEditingController();
  List<ShoppingItem> _activeItems = [];
  List<ShoppingItem> _checkedItems = [];
  List<String> _suggestions = [];
  Map<String, int> _activeIndexMap = {};
  Map<String, int> _checkedIndexMap = {};
  int _activeSignature = 0;
  int _checkedSignature = 0;
  int _historySignature = 0;

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onRepoChanged);
    _refreshFromRepo(forceSuggestions: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshFromRepo();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onRepoChanged() => _refreshFromRepo();

  int _itemsSignature(Iterable<ShoppingItem> items) {
    return Object.hashAll(items.map((item) => Object.hash(item.id, item.isChecked)));
  }

  int _historySig(List<ShoppingHistoryItem> history) {
    if (history.isEmpty) return 0;
    var latest = 0;
    for (final item in history) {
      final ts = item.date.millisecondsSinceEpoch;
      if (ts > latest) latest = ts;
    }
    return Object.hash(history.length, latest);
  }

  void _refreshFromRepo({bool forceSuggestions = false}) {
    final allItems = widget.repo.getShoppingList();
    final activeItems = allItems.where((i) => !i.isChecked).toList();
    final checkedItems = allItems.where((i) => i.isChecked).toList();
    final activeIndexMap = <String, int>{};
    for (var i = 0; i < activeItems.length; i++) {
      activeIndexMap[activeItems[i].id] = i;
    }
    final checkedIndexMap = <String, int>{};
    for (var i = 0; i < checkedItems.length; i++) {
      checkedIndexMap[checkedItems[i].id] = i;
    }
    final activeSignature = _itemsSignature(activeItems);
    final checkedSignature = _itemsSignature(checkedItems);
    final historySignature = _historySig(widget.repo.shoppingHistory);

    final shouldUpdateSuggestions = forceSuggestions ||
        activeSignature != _activeSignature ||
        historySignature != _historySignature;

    if (!shouldUpdateSuggestions &&
        activeSignature == _activeSignature &&
        checkedSignature == _checkedSignature) {
      return;
    }

    setState(() {
      _activeItems = activeItems;
      _checkedItems = checkedItems;
      _activeIndexMap = activeIndexMap;
      _checkedIndexMap = checkedIndexMap;
      _activeSignature = activeSignature;
      _checkedSignature = checkedSignature;
      if (shouldUpdateSuggestions) {
        _suggestions = _buildSuggestions(activeItems);
        _historySignature = historySignature;
      }
    });
  }
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

  
  // Fallback suggestions when history is insufficient.
  static const List<String> _defaultSuggestions = [
    'Milk',
    'Eggs',
    'Avocado',
    'Sourdough',
    'Chicken Breast',
    'Toilet Paper',
    'Olive Oil',
    'Coffee',
    'Greek Yogurt',
    'Dark Chocolate',
  ];

  String _normalizeName(String name) => name.trim().toLowerCase();

  List<String> _buildSuggestions(List<ShoppingItem> activeItems) {
    final activeSet = activeItems.map((e) => _normalizeName(e.name)).toSet();
    final history = widget.repo.shoppingHistory;
    final Map<String, _SuggestionStat> stats = {};

    for (final item in history) {
      final name = item.name.trim();
      if (name.isEmpty) continue;
      final key = _normalizeName(name);
      final existing = stats[key];
      if (existing == null) {
        stats[key] = _SuggestionStat(name: name, count: 1, lastSeen: item.date);
      } else {
        final updatedDate = item.date.isAfter(existing.lastSeen) ? item.date : existing.lastSeen;
        stats[key] = _SuggestionStat(
          name: existing.name,
          count: existing.count + 1,
          lastSeen: updatedDate,
        );
      }
    }

    final ranked = stats.values.toList()
      ..sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) return countCompare;
        return b.lastSeen.compareTo(a.lastSeen);
      });

    final suggestions = <String>[];
    for (final stat in ranked) {
      final key = _normalizeName(stat.name);
      if (activeSet.contains(key)) continue;
      suggestions.add(stat.name);
      if (suggestions.length >= 10) break;
    }

    if (suggestions.length < 6) {
      for (final fallback in _defaultSuggestions) {
        final key = _normalizeName(fallback);
        if (activeSet.contains(key) || suggestions.any((s) => _normalizeName(s) == key)) {
          continue;
        }
        suggestions.add(fallback);
        if (suggestions.length >= 10) break;
      }
    }

    return suggestions;
  }
  
  void _showAutoDismissSnackBar(String message, {VoidCallback? onUndo}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ScaffoldMessenger.of(context).clearSnackBars();
    
    ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _addItem(String name) async {
    if (name.trim().isEmpty) return;
    HapticFeedback.lightImpact();

    final newItem = ShoppingItem(
      id: const Uuid().v4(),
      name: name.trim(),
      category: _guessCategory(name),
      isChecked: false,
    );

    await widget.repo.saveShoppingItem(newItem);
    _controller.clear();
  }

  void _addItemFromInput() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    _addItem(value);
  }

  Widget _buildInputField() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _addItemFromInput(),
      decoration: InputDecoration(
        hintText: 'Add item (e.g. Milk)',
        isDense: true,
        filled: true,
        fillColor: theme.cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
    );
  }

  Future<void> _editShoppingNote(ShoppingItem item) async {
    final controller = TextEditingController(text: item.note ?? '');
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Item note', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add a short note...',
            hintStyle: TextStyle(color: colors.onSurface.withOpacity(0.5)),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E2229) : const Color(0xFFF5F7FA),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.outline.withOpacity(0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.outline.withOpacity(0.3)),
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await widget.repo.updateShoppingItemNote(item, result);
    }
  }

  String _guessCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('peanut butter')) return 'pantry';
    if (n.contains('milk') || n.contains('yogurt') || n.contains('cheese') || n.contains('egg')) return 'dairy'; 
    if (n.contains('cat') || n.contains('dog') || n.contains('pet') || n.contains('hay')) return 'pet';
    if (n.contains('paper') || n.contains('tissue') || n.contains('soap') || n.contains('clean')) return 'household';
    if (n.contains('frozen') || n.contains('ice cream') || n.contains('pizza')) return 'frozen';
    if (n.contains('water') || n.contains('juice') || n.contains('coffee') || n.contains('beer')) return 'beverage';
    if (n.contains('bread') || n.contains('cake') || n.contains('flour')) return 'bakery';
    if (n.contains('fish') || n.contains('salmon') || n.contains('shrimp')) return 'seafood';
    if (n.contains('chicken') || n.contains('beef') || n.contains('steak') || n.contains('meat')) return 'meat';
    if (n.contains('apple') || n.contains('banana') || n.contains('tomato') || n.contains('veg')) return 'produce';
    if (n.contains('chip') || n.contains('nut') || n.contains('chocolate') || n.contains('snack')) return 'snacks';
    if (n.contains('rice') || n.contains('pasta') || n.contains('oil') || n.contains('sauce') || n.contains('soup') || n.contains('salt')) return 'pantry';
    return 'general';
  }

  Future<void> _moveCheckedToInventory(BuildContext context, List<ShoppingItem> checkedItems) async {
    HapticFeedback.mediumImpact();
    await widget.repo.checkoutShoppingItems(checkedItems);
    if (context.mounted) {
      _showAutoDismissSnackBar('${checkedItems.length} items moved to Inventory! 🧊');
    }
  }

  void _showAiImportSheet() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddByRecipeSheet(repo: widget.repo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    const primary = Color(0xFF005F87);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Shopping List',
          style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        actions: [
          _wrapShowcase(
            key: widget.fridgeKey,
            title: 'Fridge Camera',
            description: 'Have a sight inside your fridge to know what to buy',
            child: IconButton(
              tooltip: 'Fridge Camera',
              icon: Icon(Icons.kitchen_rounded, color: colors.onSurface),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FridgeCameraPage()),
                );
              },
            ),
          ),
          _wrapShowcase(
            key: widget.historyKey,
            title: 'Purchase History',
            description: 'Review items you marked as bought.',
            child: IconButton(
              tooltip: 'Purchase History',
              icon: Icon(Icons.history_rounded, color: colors.onSurface),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShoppingArchivePage(
                      repo: widget.repo,
                      onAddBack: (name, category) => _addItem(name),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final allItemsEmpty = _activeItems.isEmpty && _checkedItems.isEmpty;
          final bottomInset = MediaQuery.of(context).padding.bottom;
          const tabBarHeight = 64.0;
          const tabBarMargin = 20.0;
          final tabBarSpace = bottomInset + tabBarHeight + tabBarMargin;
          final listBottomPadding = tabBarSpace + (_checkedItems.isNotEmpty ? 140.0 : 100.0);
          return RefreshIndicator(
            color: primary,
            onRefresh: widget.repo.refreshAll,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_suggestions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: SizedBox(
                        height: 60,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: _suggestions.length,
                          itemBuilder: (ctx, i) {
                            final sug = _suggestions[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: BouncingButton(
                                onTap: () => _addItem(sug),
                                child: Chip(
                                  elevation: 0,
                                  side: BorderSide(color: primary.withOpacity(0.1)),
                                  backgroundColor: theme.cardColor,
                                  label: Text(
                                    sug,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
                                  ),
                                  avatar: const Icon(Icons.add_rounded, size: 16, color: primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                if (allItemsEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: RepaintBoundary(child: _buildEmptyState()),
                  )
                else ...[
                  SliverPadding(
                    // ð¢ å¢å åºé¨ Padding (220) ä»¥ç¡®ä¿åè¡¨åå®¹ä¸è¢«å é«ç BottomSheet é®æ¡
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _activeItems[index];
                          return RepaintBoundary(
                            key: ValueKey(item.id),
                            child: _buildDismissibleItem(item),
                          );
                        },
                        childCount: _activeItems.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        addSemanticIndexes: false,
                        findChildIndexCallback: (key) {
                          if (key is ValueKey<String>) {
                            return _activeIndexMap[key.value];
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  if (_activeItems.isNotEmpty && _checkedItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'COMPLETED',
                                style: TextStyle(
                                  color: colors.onSurface.withOpacity(0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, listBottomPadding),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _checkedItems[index];
                          return RepaintBoundary(
                            key: ValueKey(item.id),
                            child: _buildDismissibleItem(item),
                          );
                        },
                        childCount: _checkedItems.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        addSemanticIndexes: false,
                        findChildIndexCallback: (key) {
                          if (key is ValueKey<String>) {
                            return _checkedIndexMap[key.value];
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      bottomSheet: Builder(
        builder: (context) {
          final bottomInset = MediaQuery.of(context).padding.bottom;
          const tabBarHeight = 64.0;
          const tabBarMargin = 20.0;
          final tabBarSpace = bottomInset + tabBarHeight + tabBarMargin;

          return Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            // ð¢ å³é®è°æ´ï¼åºé¨Padding å¢å å°safeArea + 100
            // è¿æ ·è¾å¥æ¡å AI æé®ä¼ä½äºæ¬æµ®å¯¼èªæ ä¸æ¹ (æ¬æµ®æ çº¦é«84px)
            padding: EdgeInsets.fromLTRB(20, 16, 20, tabBarSpace + 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_checkedItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BouncingButton(
                      onTap: () => _moveCheckedToInventory(context, _checkedItems),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text('Move ${_checkedItems.length} items to Fridge',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(),
                    ),
                    const SizedBox(width: 12),
                    _wrapShowcase(
                      key: widget.aiKey,
                      title: 'AI Smart Add',
                      description: 'Add items from a recipe',
                      child: IconButton(
                        onPressed: _showAiImportSheet,
                        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                        padding: const EdgeInsets.all(14),
                        style: IconButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _wrapShowcase(
                      key: widget.addKey,
                      title: 'Quick Add',
                      description: 'Tap to add item',
                      child: IconButton(
                        onPressed: _addItemFromInput,
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        padding: const EdgeInsets.all(14),
                        style: IconButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDismissibleItem(ShoppingItem item) {
    final ownerLabel = _resolveOwnerLabel(item);
    final buyerLabel = item.isChecked ? widget.repo.getBuyerNameForItemId(item.id) : null;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        widget.repo.deleteShoppingItem(item);
        _showAutoDismissSnackBar(
          'Deleted "${item.name}"',
          onUndo: () => widget.repo.saveShoppingItem(item),
        );
      },
      child: _ShoppingTile(
        item: item,
        ownerLabel: ownerLabel,
        buyerLabel: buyerLabel,
        onToggle: () {
          HapticFeedback.selectionClick();
          widget.repo.toggleShoppingItemStatus(item);
        },
        onLongPress: () => _editShoppingNote(item),
      ),
    );
  }

  String? _resolveOwnerLabel(ShoppingItem item) {
    if (!widget.repo.isSharedUsage) return null;
    final name = item.ownerName?.trim();
    if (name != null && name.isNotEmpty) {
      return name == 'Me' ? widget.repo.currentUserName : name;
    }
    return widget.repo.currentUserName;
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor),
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: colors.onSurface.withOpacity(isDark ? 0.35 : 0.25),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your list is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items manually or use recipe import.',
            style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _UserAvatarTag extends StatelessWidget {
  final String name;
  final double size;
  const _UserAvatarTag({required this.name, this.size = 20});

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
      width: size, height: size,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
      ),
      alignment: Alignment.center,
      child: Text(initial, style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}

class _ShoppingTile extends StatelessWidget {
  final ShoppingItem item;
  final String? ownerLabel;
  final String? buyerLabel;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;
  const _ShoppingTile({
    required this.item,
    required this.onToggle,
    this.ownerLabel,
    this.buyerLabel,
    this.onLongPress,
  });

  Color _itemColor(ShoppingItem item) {
    final n = item.name.toLowerCase();
    if (n.contains('milk') || n.contains('yogurt') || n.contains('cheese')) {
      return const Color(0xFF42A5F5);
    }
    if (n.contains('egg')) return const Color(0xFFFFB300);
    if (n.contains('apple') || n.contains('banana') || n.contains('tomato') || n.contains('veg')) {
      return const Color(0xFF66BB6A);
    }
    if (n.contains('fish') || n.contains('salmon') || n.contains('shrimp')) {
      return const Color(0xFF5C6BC0);
    }
    if (n.contains('chicken') || n.contains('beef') || n.contains('pork') || n.contains('meat')) {
      return const Color(0xFFEF5350);
    }
    if (n.contains('bread') || n.contains('croissant') || n.contains('cake')) {
      return const Color(0xFFFFB300);
    }
    if (n.contains('coffee') || n.contains('tea')) return const Color(0xFF26A69A);
    if (n.contains('water') || n.contains('juice')) return const Color(0xFF26A69A);
    if (n.contains('snack') || n.contains('chip') || n.contains('chocolate')) {
      return const Color(0xFFFF7043);
    }
    if (n.contains('rice') || n.contains('pasta') || n.contains('noodle') || n.contains('oil')) {
      return const Color(0xFFFFA726);
    }
    switch (item.category) {
      case 'pet': return const Color(0xFF8D6E63);
      case 'household': return const Color(0xFF78909C);
      case 'frozen': return const Color(0xFF4DD0E1);
      case 'beverage': return const Color(0xFF26A69A);
      case 'bakery': return const Color(0xFFFFB300);
      case 'dairy': return const Color(0xFF42A5F5);
      case 'seafood': return const Color(0xFF5C6BC0);
      case 'meat': return const Color(0xFFEF5350);
      case 'produce': return const Color(0xFF66BB6A);
      case 'snacks': return const Color(0xFFFF7043);
      case 'pantry': return const Color(0xFFFFA726);
      default: return Colors.grey.shade400;
    }
  }

  IconData _itemIcon(ShoppingItem item) {
    final n = item.name.toLowerCase();
    if (n.contains('milk') || n.contains('yogurt') || n.contains('cheese')) {
      return Icons.local_drink_rounded;
    }
    if (n.contains('egg')) return Icons.egg_rounded;
    if (n.contains('apple') || n.contains('banana') || n.contains('tomato') || n.contains('veg')) {
      return Icons.eco_rounded;
    }
    if (n.contains('fish') || n.contains('salmon') || n.contains('shrimp')) {
      return Icons.set_meal_rounded;
    }
    if (n.contains('chicken') || n.contains('beef') || n.contains('pork') || n.contains('meat')) {
      return Icons.restaurant_rounded;
    }
    if (n.contains('bread') || n.contains('croissant') || n.contains('cake')) {
      return Icons.bakery_dining_rounded;
    }
    if (n.contains('coffee') || n.contains('tea')) return Icons.local_cafe_rounded;
    if (n.contains('water') || n.contains('juice')) return Icons.local_drink_rounded;
    if (n.contains('snack') || n.contains('chip') || n.contains('chocolate')) {
      return Icons.cookie_rounded;
    }
    if (n.contains('rice') || n.contains('pasta') || n.contains('noodle') || n.contains('oil')) {
      return Icons.kitchen_rounded;
    }
    switch (item.category) {
      case 'pet': return Icons.pets_rounded;
      case 'household': return Icons.cleaning_services_rounded;
      case 'frozen': return Icons.ac_unit_rounded;
      case 'beverage': return Icons.local_drink_rounded;
      case 'bakery': return Icons.bakery_dining_rounded;
      case 'dairy': return Icons.water_drop_rounded; 
      case 'seafood': return Icons.set_meal_rounded;
      case 'meat': return Icons.restaurant_rounded;
      case 'produce': return Icons.eco_rounded;
      case 'snacks': return Icons.cookie_rounded;
      case 'pantry': return Icons.kitchen_rounded;
      default: return Icons.shopping_bag_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _itemColor(item);
    final isDone = item.isChecked;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final badgeLabel = (item.isChecked && buyerLabel != null && buyerLabel!.isNotEmpty)
        ? buyerLabel
        : ownerLabel;

    return BouncingButton(
      onTap: onToggle,
      onLongPress: onLongPress,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDone ? 0.4 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDone
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isDone ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDone ? color : colors.onSurface.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
                const SizedBox(width: 14),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Icon(_itemIcon(item), size: 18, color: color),
                    ),
                    if (badgeLabel != null && badgeLabel!.isNotEmpty)
                      Positioned(right: -5, bottom: -5, child: _UserAvatarTag(name: badgeLabel!, size: 16)),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: isDone ? colors.onSurface.withOpacity(0.5) : colors.onSurface,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (item.note != null && item.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withOpacity(0.55),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionStat {
  final String name;
  final int count;
  final DateTime lastSeen;

  const _SuggestionStat({
    required this.name,
    required this.count,
    required this.lastSeen,
  });
}

class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  const BouncingButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }
    return GestureDetector(
      onTapDown: (_) {
        if (widget.enabled) {
          _controller!.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (widget.enabled) {
          _controller!.reverse();
          widget.onTap();
        }
      },
      onTapCancel: () {
        if (widget.enabled) _controller!.reverse();
      },
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - _controller!.value,
          child: widget.child,
        ),
      ),
    );
  }
}
