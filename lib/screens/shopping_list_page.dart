// lib/screens/shopping_list_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_haptics.dart';
import 'package:flutter/services.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';

import '../repositories/inventory_repository.dart';
import '../repositories/guest_shopping_repository.dart';
import '../utils/app_typography.dart';
import '../utils/auth_guard.dart';
import '../utils/reveal_route.dart';
import '../utils/share_link_builder.dart';
import '../utils/showcase_utils.dart';
import '../widgets/add_by_recipe_sheet.dart'; 
import '../widgets/pull_to_refresh_cue.dart';
import 'guest_shopping_archive_page.dart';
import 'guest_shopping_list_page.dart';
import 'shopping_archive_page.dart';

class ShoppingListPageWrapper extends StatefulWidget {
  final InventoryRepository repo;
  final bool isActive;

  const ShoppingListPageWrapper({
    super.key,
    required this.repo,
    required this.isActive,
  });

  @override
  State<ShoppingListPageWrapper> createState() => _ShoppingListPageWrapperState();
}

class _ShoppingListPageWrapperState extends State<ShoppingListPageWrapper> {
  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _aiKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();
  bool _didShow = false;

  Future<void> _maybeShowTutorial(BuildContext context) async {
    await ShowcaseCoordinator.startPageShowcase(
      context: context,
      hasAttempted: _didShow,
      markAttempted: () => _didShow = true,
      isPageVisibleNow: () => mounted && widget.isActive,
      isDataReadyNow: () => !widget.repo.isLoading,
      seenPrefKey: 'hasShownIntro_shopping_v1',
      keys: [_addKey, _aiKey, _historyKey],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) {
        if (widget.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial(context));
        }
        return ShoppingListPage(
          repo: widget.repo,
          addKey: _addKey,
          aiKey: _aiKey,
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
  final GlobalKey? historyKey;

  const ShoppingListPage({
    super.key,
    required this.repo,
    this.addKey,
    this.aiKey,
    this.historyKey,
  });

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  late final ScrollController _scrollController;
  List<ShoppingItem> _activeItems = [];
  List<ShoppingItem> _checkedItems = [];
  List<String> _suggestions = [];
  Map<String, int> _activeIndexMap = {};
  Map<String, int> _checkedIndexMap = {};
  int _activeSignature = 0;
  int _checkedSignature = 0;
  int _historySignature = 0;
  double _lastViewInset = 0;
  bool _didFireRefreshThresholdHaptic = false;
  double _refreshPullDistance = 0;
  double _refreshVisualProgress = 0;
  bool _refreshVisualArmed = false;

  // Inline Editing State
  String? _editingItemId;
  final TextEditingController _renameController = TextEditingController();
  final FocusNode _renameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    widget.repo.addListener(_onRepoChanged);
    _refreshFromRepo(forceSuggestions: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastViewInset = MediaQuery.of(context).viewInsets.bottom;
    _refreshFromRepo();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChanged);
    _controller.dispose();
    _renameController.dispose();
    _renameFocusNode.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final inset = _currentViewInset();
    if (_lastViewInset > 0 && inset == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
    }
    _lastViewInset = inset;
  }

  double _currentViewInset() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 0;
    final view = views.first;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  void _restoreScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final current = position.pixels;
    if (current > max) {
      _scrollController.jumpTo(max);
      return;
    }
    if (max - current < 120) {
      _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _onRepoChanged() => _refreshFromRepo();

   int _itemsSignature(Iterable<ShoppingItem> items) {
  return Object.hashAll(
    items.map(
      (item) => Object.hash(
        item.id,
        item.isChecked,
        item.name,
        item.category,
        item.note,
        item.createdAt?.millisecondsSinceEpoch,
        item.updatedAt?.millisecondsSinceEpoch,
      ),
    ),
  );
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
  
  // ================== Inline Editing Logic ==================

  void _startInlineEdit(ShoppingItem item) {
    AppHaptics.selection();
    setState(() {
      _editingItemId = item.id;
      _controller.clear(); 
      _renameController.text = item.name;
    });
    // Delay focus to allow rebuild
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _renameFocusNode.requestFocus();
      }
    });
  }

  void _cancelInlineEdit() {
    _renameFocusNode.unfocus();
    setState(() {
      _editingItemId = null;
    });
  }

  Future<void> _saveInlineEdit(ShoppingItem item) async {
    final newName = _renameController.text.trim();
    
    setState(() {
      _editingItemId = null;
    });

    if (newName.isNotEmpty && newName != item.name) {
      final updated = ShoppingItem(
        id: item.id,
        name: newName,
        category: item.category,
        isChecked: item.isChecked,
        ownerName: item.ownerName,
        userId: item.userId,
        note: item.note,
        createdAt: item.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await widget.repo.saveShoppingItem(updated); 
      AppHaptics.success();
    }
  }

  // ================== End Inline Editing Logic ==================

  Widget _wrapShowcase({
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
    final l10n = AppLocalizations.of(context);
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
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      l10n?.shoppingUndoAction ?? 'Undo',
                      style: const TextStyle(
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

  Future<void> _addItem(String name) async {
    if (name.trim().isEmpty) return;
    AppHaptics.selection();

    final newItem = ShoppingItem(
      id: const Uuid().v4(),
      name: name.trim(),
      category: _guessCategory(name),
      isChecked: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await widget.repo.saveShoppingItem(newItem);
    AppHaptics.success();
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
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)?.shoppingInputHint ?? 'Add item here',
        isDense: true,
        filled: true,
        fillColor: theme.cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
    );
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
    AppHaptics.success();
    await widget.repo.checkoutShoppingItems(checkedItems);
    AppHaptics.error();
    if (context.mounted) {
    }
  }

  void _showAiImportSheet() {
    AppHaptics.error();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddByRecipeSheet(repo: widget.repo),
    );
  }

  void _openGuestListMenu(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.group_add_rounded),
                title: Text(
                  l10n?.shoppingGuestCreateTempTitle ?? 'Create temporary list',
                ),
                subtitle: Text(
                  l10n?.shoppingGuestCreateTempSubtitle ??
                      'Generate a shareable guest list',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _createGuestList();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_shared_rounded),
                title: Text(l10n?.shoppingGuestMyListsTitle ?? 'My guest lists'),
                subtitle: Text(
                  l10n?.shoppingGuestMyListsSubtitle ??
                      'Lists you participated in',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await requireLogin(context);
                  if (!ok) return;
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GuestShoppingArchivePage()),
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

  Future<void> _createGuestList() async {
    final l10n = AppLocalizations.of(context);
    final ok = await requireLogin(context);
    if (!ok) return;
    if (!mounted) return;

    final titleController = TextEditingController();
    int days = 1;
    bool attachToMe = true;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                l10n?.shoppingGuestDialogTitle ?? 'Create Temporary List',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText:
                          l10n?.shoppingGuestTitleHint ?? 'e.g. Dinner Party',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: days,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 12,
                    menuMaxHeight: 360,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    decoration: InputDecoration(
                      labelText: l10n?.shoppingGuestExpiresIn ?? 'Expires in',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 1,
                        child: Text(l10n?.shoppingGuestExpire24h ?? '24 hours'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text(l10n?.shoppingGuestExpire3d ?? '3 days'),
                      ),
                      DropdownMenuItem(
                        value: 7,
                        child: Text(l10n?.shoppingGuestExpire7d ?? '7 days'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() => days = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: attachToMe,
                    onChanged: (value) => setStateDialog(() => attachToMe = value),
                    title: Text(
                      l10n?.shoppingGuestAttachMineTitle ?? 'Attach to my account',
                    ),
                    subtitle: Text(
                      l10n?.shoppingGuestAttachMineSubtitle ??
                          'Shows in your account for later reuse',
                      style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n?.cancel ?? 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n?.shoppingGuestCreateAction ?? 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final list = await GuestShoppingRepository.createList(
      title: titleController.text,
      expiresIn: Duration(days: days),
      attachToOwner: attachToMe,
    );

    if (!mounted) return;

    final shareUrl = _buildShareUrl(
      listId: list.id,
      shareToken: list.shareToken,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.shoppingShareLinkTitle ?? 'Share this link',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SelectableText(
                shareUrl,
                style: TextStyle(color: colors.onSurface.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        Navigator.pop(context);
                        _showAutoDismissSnackBar(
                          l10n?.shoppingLinkCopied ?? 'Link copied.',
                        );
                      },
                      child: Text(l10n?.shoppingCopyLink ?? 'Copy Link'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GuestShoppingListPage(shareToken: list.shareToken),
                          ),
                        );
                      },
                      child: Text(l10n?.shoppingOpenList ?? 'Open List'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildShareUrl({
    required String listId,
    String? shareToken,
  }) {
    final identifier = listId.trim().isNotEmpty ? listId.trim() : (shareToken ?? '').trim();
    return buildGuestShareUrl(identifier);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final primary = colors.primary;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          l10n?.navShopping ?? 'Shopping List',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: kMainPageTitleFontSize,
            color: colors.onSurface,
          ),
        ),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        actions: [
          IconButton(
            tooltip: l10n?.shoppingTemporaryListTooltip ?? 'Temporary List',
            icon: Icon(Icons.group_add_rounded, color: colors.onSurface),
            onPressed: () => _openGuestListMenu(context),
          ),
          _wrapShowcase(
            key: widget.fridgeKey,
            title: l10n?.shoppingFridgeCameraTitle ?? 'Fridge Camera',
            description: l10n?.shoppingFridgeCameraDescription ?? 'Scan your fridge to speed up planning.',
            child: IconButton(
              tooltip: l10n?.shoppingFridgeCameraTitle ?? 'Fridge Camera',
              icon: Icon(Icons.kitchen_rounded, color: colors.onSurface),
              onPressed: () {
                Navigator.push(
                  context,
                  topRightRevealRoute(const FridgeCameraPage()),
                );
              },
            ),
          ),
          _wrapShowcase(
            key: widget.historyKey,
            title: l10n?.shoppingPurchaseHistoryTitle ?? 'Purchase History',
            description: l10n?.shoppingPurchaseHistoryDescription ?? 'Review bought items and add them back.',
            child: IconButton(
              tooltip: l10n?.shoppingPurchaseHistoryTitle ?? 'Purchase History',
              icon: Icon(Icons.history_rounded, color: colors.onSurface),
              onPressed: () {
                Navigator.push(
                  context,
                  topRightRevealRoute(
                    ShoppingArchivePage(
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
          return Stack(
            children: [
              RefreshIndicator(
                color: Colors.transparent,
                backgroundColor: Colors.transparent,
                strokeWidth: 0.1,
                elevation: 0,
                onRefresh: _onRefreshWithFeedback,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleRefreshPullNotification,
                  child: CustomScrollView(
              controller: _scrollController,
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
                                  side: BorderSide(color: primary.withValues(alpha: 0.1)),
                                  backgroundColor: theme.cardColor,
                                  label: Text(
                                    sug,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
                                  ),
                                  avatar: Icon(Icons.add_rounded, size: 16, color: primary),
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
                                l10n?.shoppingCompletedLabel ?? 'COMPLETED',
                                style: TextStyle(
                                  color: colors.onSurface.withValues(alpha: 0.4),
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
                ),
              ),
              PullToRefreshCue(
                progress: _refreshVisualProgress,
                armed: _refreshVisualArmed,
                color: primary,
                hintText: l10n?.pullToRefreshHint ?? 'Pull to refresh',
                releaseText: l10n?.pullToRefreshRelease ?? 'Release to refresh',
              ),
            ],
          );
        },
      ),
      bottomSheet: Builder(
        builder: (context) {
          final bottomInset = MediaQuery.of(context).padding.bottom;
          const tabBarHeight = 64.0;
          const tabBarMargin = 20.0;
          final tabBarSpace = bottomInset + tabBarHeight + tabBarMargin;
          const sheetGap = 10.0;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, tabBarSpace + sheetGap),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF111827).withValues(alpha: 0.84)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_checkedItems.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                            button: true,
                            label:
                                l10n?.shoppingMoveCheckedSemLabel ??
                                    'Move checked items to fridge',
                            hint: l10n?.shoppingMoveCheckedSemHint(
                                  _checkedItems.length.toString(),
                                ) ??
                                'Moves ${_checkedItems.length} completed items into inventory',
                            child: BouncingButton(
                              onTap: () => _moveCheckedToInventory(context, _checkedItems),
                              child: Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      l10n?.shoppingMoveCheckedToFridge(
                                            _checkedItems.length.toString(),
                                          ) ??
                                          'Move ${_checkedItems.length} items to Fridge',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
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
                            title: l10n?.shoppingAiSmartAddTitle ?? 'AI Smart Add',
                            description: l10n?.shoppingAiSmartAddDescription ?? 'Add ingredients from a recipe.',
                            child: Semantics(
                              button: true,
                              label: l10n?.shoppingAiSmartAddTitle ?? 'AI smart add',
                              hint: l10n?.shoppingAiSmartAddHint ?? 'Import ingredients from recipe text',
                              child: IconButton(
                                tooltip: l10n?.shoppingAiSmartAddTitle ?? 'AI Smart Add',
                                onPressed: _showAiImportSheet,
                                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                                constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                                padding: const EdgeInsets.all(14),
                                style: IconButton.styleFrom(
                                  backgroundColor: primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _wrapShowcase(
                            key: widget.addKey,
                            title: l10n?.shoppingQuickAddTitle ?? 'Quick Add',
                            description: l10n?.shoppingQuickAddDescription ?? 'Add one item instantly.',
                            child: Semantics(
                              button: true,
                              label: l10n?.shoppingQuickAddSemanticsLabel ?? 'Quick add item',
                              hint: 'Add the current text as a shopping item',
                              child: IconButton(
                                tooltip: l10n?.shoppingQuickAddTitle ?? 'Quick Add',
                                onPressed: _addItemFromInput,
                                icon: const Icon(Icons.add_rounded, color: Colors.white),
                                constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                                padding: const EdgeInsets.all(14),
                                style: IconButton.styleFrom(
                                  backgroundColor: primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDismissibleItem(ShoppingItem item) {
    final ownerLabel = _resolveOwnerLabel(item);
    final buyerLabel = (item.isChecked && widget.repo.isSharedUsage)
        ? widget.repo.getBuyerNameForItemId(item.id)
        : null;
    
    // Check if item is being edited
    final isEditing = _editingItemId == item.id;

    return Dismissible(
      key: ValueKey(item.id),
      // Disable dismiss when editing
      direction: isEditing ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
      ),
      onDismissed: (_) {
        AppHaptics.success();
        widget.repo.deleteShoppingItem(item);
        final l10n = AppLocalizations.of(context);
        _showAutoDismissSnackBar(
          l10n?.shoppingDeletedToast(item.name) ?? 'Deleted "${item.name}"',
          onUndo: () => widget.repo.saveShoppingItem(item),
        );
      },
      child: _ShoppingTile(
        item: item,
        ownerLabel: ownerLabel,
        buyerLabel: buyerLabel,
        isEditing: isEditing,
        editController: _renameController,
        editFocusNode: _renameFocusNode,
        onSaveEdit: () => _saveInlineEdit(item),
        onCancelEdit: _cancelInlineEdit,
        onToggle: () {
          if (isEditing) {
            _saveInlineEdit(item);
          } else {
            AppHaptics.selection();
            widget.repo.toggleShoppingItemStatus(item);
          }
        },
        // Trigger inline edit on long press
        onLongPress: () => _startInlineEdit(item),
      ),
    );
  }

  String? _resolveOwnerLabel(ShoppingItem item) {
    if (!widget.repo.isSharedUsage) return null;

    final byOwnerName = item.ownerName?.trim();
    if (byOwnerName != null && byOwnerName.isNotEmpty) {
      return byOwnerName == 'Me' ? widget.repo.currentUserName : byOwnerName;
    }

    final byUserId = widget.repo.resolveUserNameById(item.userId)?.trim();
    if (byUserId != null && byUserId.isNotEmpty) {
      return byUserId;
    }

    // Stable fallback: keep badge visible even if remote owner metadata
    // is not hydrated yet.
    final fallback = widget.repo.currentUserName.trim();
    if (fallback.isNotEmpty) return fallback;
    return 'Family';
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
              color: colors.onSurface.withValues(alpha: isDark ? 0.35 : 0.25),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)?.shoppingEmptyTitle ?? 'Your list is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.shoppingEmptySubtitle ?? 'Add items manually or use recipe import.',
            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6), fontSize: 14),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2)],
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

  // Edit props
  final bool isEditing;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final VoidCallback? onSaveEdit;
  final VoidCallback? onCancelEdit;

  const _ShoppingTile({
    required this.item,
    required this.onToggle,
    this.ownerLabel,
    this.buyerLabel,
    this.onLongPress,
    this.isEditing = false,
    this.editController,
    this.editFocusNode,
    this.onSaveEdit,
    this.onCancelEdit,
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

  (String label, DateTime? time) _resolveChangeMeta(ShoppingItem item) {
    final createdAt = item.createdAt;
    final updatedAt = item.updatedAt;
    if (createdAt != null && updatedAt != null) {
      final changed = updatedAt.difference(createdAt).abs() > const Duration(minutes: 1);
      return (changed ? 'Updated' : 'Added', changed ? updatedAt : createdAt);
    }
    if (updatedAt != null) return ('Added', updatedAt);
    if (createdAt != null) return ('Added', createdAt);
    return ('', null);
  }

  String _formatMetaTime(DateTime time) {
    final local = time;
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (isToday) return '$hh:$mm';
    final mon = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$mon/$day $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = _itemColor(item);
    final isDone = item.isChecked;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final editBorderColor = colors.primary.withValues(alpha: isDark ? 0.8 : 0.55);
    final editTint = isDark
        ? colors.primary.withValues(alpha: 0.14)
        : colors.primary.withValues(alpha: 0.08);
    final editInputBg = isDark
        ? colors.primary.withValues(alpha: 0.16)
        : colors.primary.withValues(alpha: 0.10);
    final changeMeta = _resolveChangeMeta(item);
    final changeLabel = changeMeta.$1;
    final changeTime = changeMeta.$2;

    final badgeLabel = (item.isChecked && buyerLabel != null && buyerLabel!.isNotEmpty)
        ? buyerLabel
        : ownerLabel;

    return BouncingButton(
      enabled: !isEditing, // Disable bouncing when editing
      onTap: onToggle,
      onLongPress: onLongPress,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDone ? 0.4 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isEditing ? Color.alphaBlend(editTint, theme.cardColor) : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: isEditing ? Border.all(color: editBorderColor, width: 1.8) : null,
            boxShadow: isEditing
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: isDark ? 0.24 : 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : isDone
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
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
                      color: isDone ? color : colors.onSurface.withValues(alpha: 0.2),
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
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: Icon(_itemIcon(item), size: 18, color: color),
                    ),
                    if (badgeLabel != null && badgeLabel.isNotEmpty)
                      Positioned(right: -5, bottom: -5, child: _UserAvatarTag(name: badgeLabel, size: 16)),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEditing)
                        Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l10n?.shoppingEditingItem ?? 'Editing item',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      if (isEditing) ...[
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: editInputBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: editController,
                            focusNode: editFocusNode,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              border: InputBorder.none,
                              hintText:
                                  l10n?.shoppingRenameItemHint ?? 'Rename item',
                              hintStyle: TextStyle(
                                color: colors.onSurface.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => onSaveEdit?.call(),
                          ),
                        ),
                      ]
                      else
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: isDone ? colors.onSurface.withValues(alpha: 0.5) : colors.onSurface,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      if (!isEditing && item.note != null && item.note!.trim().isNotEmpty) ...[
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
                if (isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Cancel',
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.onSurface.withValues(alpha: 0.65),
                        ),
                        onPressed: onCancelEdit,
                        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Save',
                        icon: Icon(Icons.check_circle_rounded, color: colors.primary),
                        onPressed: onSaveEdit,
                        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  )
                else if (changeTime != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        changeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface.withValues(alpha: 0.58),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatMetaTime(changeTime),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface.withValues(alpha: 0.46),
                        ),
                      ),
                    ],
                  )
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
          AppHaptics.selection();
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







