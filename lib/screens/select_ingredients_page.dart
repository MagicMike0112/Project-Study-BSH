// lib/screens/select_ingredients_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../utils/food_icon_mapping.dart';
import '../utils/app_locale.dart';
import '../utils/auth_guard.dart';
import '../l10n/app_localizations.dart';
import 'select_ingredients/recipe_archive_store.dart';
import 'select_ingredients/recipe_suggestion.dart';

part 'select_ingredients/recipe_archive_page_part.dart';
part 'select_ingredients/recipe_detail_page_part.dart';
part 'select_ingredients/recipe_generator_part.dart';

// ================== Global UI Constants ==================

class AppStyle {
  static const Color primary = Color(0xFF1B78FF);
  static const double cardRadius = 20.0;
  static Color bg(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color cardColor(BuildContext context) => Theme.of(context).cardColor;
  static List<BoxShadow> softShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

enum _FilterKey { all, expiring, veggie, meat, dairy }

// ================== Main Page: Select Ingredients ==================

class SelectIngredientsPage extends StatefulWidget {
  final InventoryRepository repo;
  final List<FoodItem> preselectedExpiring;

  const SelectIngredientsPage({
    super.key,
    required this.repo,
    required this.preselectedExpiring,
  });

  @override
  State<SelectIngredientsPage> createState() => _SelectIngredientsPageState();
}

class _SelectIngredientsPageState extends State<SelectIngredientsPage> {
  late List<FoodItem> _activeItems;
  final Set<String> _selectedIds = {};
  final List<String> _extraIngredients = [];
  final bool _addExtrasToInventory = false;

  int _servings = 2;
  bool _isStudentMode = false;

  final TextEditingController _extraController = TextEditingController();
  final TextEditingController _specialRequestController =
      TextEditingController();
  bool _hasChanged = false;
  _FilterKey _filterKey = _FilterKey.all;

  @override
  void initState() {
    super.initState();
    _activeItems = widget.repo.getActiveItems();
    _sortActiveItems();
    for (final item in widget.preselectedExpiring) {
      _selectedIds.add(item.id);
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isStudentMode = sp.getBool('student_mode') ?? false;
      });
    }
  }

  @override
  void dispose() {
    _extraController.dispose();
    _specialRequestController.dispose();
    super.dispose();
  }

  void _toggleSelected(FoodItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _updateServings(int delta) {
    setState(() {
      _servings = (_servings + delta).clamp(1, 10);
    });
  }

  void _addExtraIngredient() {
    final text = _extraController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _extraIngredients.add(text);
      _extraController.clear();
    });
  }

  void _removeExtraIngredient(String ing) {
    setState(() {
      _extraIngredients.remove(ing);
    });
  }

  void _resetSelection() {
    setState(() {
      _selectedIds.clear();
      _extraIngredients.clear();
      _extraController.clear();
      _specialRequestController.clear();
      _filterKey = _FilterKey.all;
    });
  }

  Future<void> _setStudentMode(bool value) async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isStudentMode = value;
    });
    await sp.setBool('student_mode', value);
  }

  Future<void> _confirm() async {
    final ok = await requireLogin(context);
    if (!ok) return;

    final selected =
        _activeItems.where((item) => _selectedIds.contains(item.id)).toList();
    final requestText = _specialRequestController.text.trim();
    final special = requestText.isEmpty ? null : requestText;

    if (_addExtrasToInventory) {
      for (final extra in _extraIngredients) {
        await widget.repo.addItem(
          FoodItem(
            id: const Uuid().v4(),
            name: extra,
            location: StorageLocation.fridge,
            quantity: 1,
            unit: 'pcs',
            purchasedDate: DateTime.now(),
            predictedExpiry: null,
            status: FoodStatus.good,
          ),
        );
      }
      _hasChanged = true;
      setState(() {
        _activeItems = widget.repo.getActiveItems();
        _sortActiveItems();
      });
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeGeneratorSheet(
          repo: widget.repo,
          items: selected,
          extraIngredients: List.unmodifiable(_extraIngredients),
          specialRequest: special,
          servings: _servings,
          studentMode: _isStudentMode,
          onInventoryUpdated: () {
            _hasChanged = true;
            setState(() {
              _activeItems = widget.repo.getActiveItems();
              _sortActiveItems();
            });
          },
        ),
      ),
    );
  }

  void _sortActiveItems() {
    _activeItems.sort((a, b) {
      final aDays = a.daysToExpiry >= 999 ? 99999 : a.daysToExpiry;
      final bDays = b.daysToExpiry >= 999 ? 99999 : b.daysToExpiry;
      return aDays.compareTo(bDays);
    });
  }

  List<FoodItem> _filteredItems() {
    if (_filterKey == _FilterKey.all) return _activeItems;
    if (_filterKey == _FilterKey.expiring) {
      return _activeItems.where((item) => item.daysToExpiry <= 3).toList();
    }
    if (_filterKey == _FilterKey.veggie) {
      return _activeItems
          .where((item) =>
              _categoryMatch(item, ['veggie', 'vegetable', 'produce']))
          .toList();
    }
    if (_filterKey == _FilterKey.meat) {
      return _activeItems
          .where((item) => _categoryMatch(item, ['meat', 'seafood', 'protein']))
          .toList();
    }
    if (_filterKey == _FilterKey.dairy) {
      return _activeItems
          .where((item) => _categoryMatch(item, ['dairy']))
          .toList();
    }
    return _activeItems;
  }

  bool _categoryMatch(FoodItem item, List<String> keywords) {
    final raw = (item.category ?? '').toLowerCase();
    if (raw.isEmpty) return false;
    return keywords.any((k) => raw.contains(k));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedCount = _selectedIds.length;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final filteredItems = _filteredItems();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
        backgroundColor: AppStyle.bg(context),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 160),
            children: [
              _buildTopBar(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.selectIngredientsKitchenTitle ?? 'Your Kitchen',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n?.selectIngredientsSelectedCount(selectedCount) ??
                                '$selectedCount items selected for cooking',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildFilterRow(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: filteredItems.isEmpty
                    ? _EmptyHint(
                        icon: Icons.inventory_2_outlined,
                        title: l10n?.inventoryNoItemsFound ?? 'No items found',
                        subtitle: l10n?.selectIngredientsNoItemsSubtitle ??
                            'Try a different filter or add new items.',
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        cacheExtent: 680,
                        itemCount: filteredItems.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final selected = _selectedIds.contains(item.id);
                          return RepaintBoundary(
                            child: _IngredientGridCard(
                              item: item,
                              selected: selected,
                              isDark: isDark,
                              onTap: () => _toggleSelected(item),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  l10n?.selectIngredientsExtrasPrompts ?? 'Extras & Prompts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface.withValues(alpha: 0.45),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _extraController,
                        onSubmitted: (_) => _addExtraIngredient(),
                        decoration: InputDecoration(
                          hintText: l10n?.selectIngredientsAddExtraHint ??
                              'Add extra ingredients...',
                          hintStyle: TextStyle(
                              color: colors.onSurface.withValues(alpha: 0.4)),
                          filled: true,
                          fillColor: theme.cardColor,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide:
                                const BorderSide(color: AppStyle.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: FilledButton(
                        onPressed: _addExtraIngredient,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              AppStyle.primary.withValues(alpha: 0.12),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.center,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: AppStyle.primary),
                      ),
                    ),
                  ],
                ),
              ),
              if (_extraIngredients.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _extraIngredients
                        .map(
                          (e) => Chip(
                            label: Text(e,
                                style: TextStyle(color: colors.onSurface)),
                            backgroundColor: theme.cardColor,
                            side: BorderSide(color: theme.dividerColor),
                            onDeleted: () => _removeExtraIngredient(e),
                          ),
                        )
                        .toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TextField(
                  controller: _specialRequestController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n?.selectIngredientsSpecialRequestHint ??
                        'Any specific cravings or dietary restrictions?',
                    hintStyle: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppStyle.primary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.96),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              children: [
                _ServingsControl(
                  servings: _servings,
                  onDecrement: () => _updateServings(-1),
                  onIncrement: () => _updateServings(1),
                ),
                const SizedBox(width: 10),
                _StudentToggle(
                  enabled: _isStudentMode,
                  onToggle: () => _setStudentMode(!_isStudentMode),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GenerateButton(
                    enabled: selectedCount > 0 || _extraIngredients.isNotEmpty,
                    onTap: _confirm,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppStyle.bg(context),
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context, _hasChanged),
          ),
          Expanded(
            child: Center(
              child: Text(
                l10n?.selectIngredientsPageTitle ?? 'Select Ingredients',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          TextButton(
            onPressed: _resetSelection,
            child: Text(
              l10n?.selectIngredientsReset ?? 'Reset',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppStyle.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppStyle.bg(context),
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _FilterChipButton(
              label: l10n?.selectIngredientsFilterAll ?? 'All Items',
              selected: _filterKey == _FilterKey.all,
              isDark: isDark,
              onTap: () => setState(() => _filterKey = _FilterKey.all),
            ),
            _FilterChipButton(
              label: l10n?.selectIngredientsFilterExpiring ?? 'Expiring',
              selected: _filterKey == _FilterKey.expiring,
              isDark: isDark,
              dotColor: Colors.amber,
              onTap: () => setState(() => _filterKey = _FilterKey.expiring),
            ),
            _FilterChipButton(
              label: l10n?.selectIngredientsFilterVeggie ?? 'Veggie',
              selected: _filterKey == _FilterKey.veggie,
              isDark: isDark,
              onTap: () => setState(() => _filterKey = _FilterKey.veggie),
            ),
            _FilterChipButton(
              label: l10n?.selectIngredientsFilterMeat ?? 'Meat',
              selected: _filterKey == _FilterKey.meat,
              isDark: isDark,
              onTap: () => setState(() => _filterKey = _FilterKey.meat),
            ),
            _FilterChipButton(
              label: l10n?.selectIngredientsFilterDairy ?? 'Dairy',
              selected: _filterKey == _FilterKey.dairy,
              isDark: isDark,
              onTap: () => setState(() => _filterKey = _FilterKey.dairy),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientGridCard extends StatelessWidget {
  final FoodItem item;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _IngredientGridCard({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cardColor = selected
        ? AppStyle.primary.withValues(alpha: 0.12)
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final borderColor = selected
        ? AppStyle.primary
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final iconBg = isDark ? const Color(0xFF0F1723) : const Color(0xFFF1F5F9);
    final urgency = _urgencyForDays(context, item.daysToExpiry);
    final qtyText = _formatQuantity(context, item.quantity, item.unit);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: selected
                    ? Container(
                        height: 22,
                        width: 22,
                        decoration: const BoxDecoration(
                          color: AppStyle.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 14, color: Colors.white),
                      )
                    : Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: colors.onSurface.withValues(alpha: 0.2),
                              width: 2),
                        ),
                      ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    height: 96,
                    width: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _buildItemIcon(
                      selected
                          ? AppStyle.primary
                          : colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    qtyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 8,
                        width: 8,
                        decoration: BoxDecoration(
                          color: urgency.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        urgency.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: urgency.color,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForItem(FoodItem item) {
    switch (item.location) {
      case StorageLocation.fridge:
        return Icons.kitchen_rounded;
      case StorageLocation.freezer:
        return Icons.ac_unit_rounded;
      case StorageLocation.pantry:
        return Icons.shelves;
    }
  }

  Widget _buildItemIcon(Color fallbackColor) {
    final assetPath = foodIconAssetForItem(item);
    return Image.asset(
      assetPath,
      width: 64,
      height: 64,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          _iconForItem(item),
          color: fallbackColor,
          size: 28,
        );
      },
    );
  }

  _UrgencyLabel _urgencyForDays(BuildContext context, int daysToExpiry) {
    final l10n = AppLocalizations.of(context);
    if (daysToExpiry < 0) {
      return _UrgencyLabel(l10n?.todayExpired ?? 'Expired', Colors.red);
    }
    if (daysToExpiry == 0) {
      return _UrgencyLabel(l10n?.todayExpiryToday ?? 'Today', Colors.redAccent);
    }
    if (daysToExpiry <= 2) {
      return _UrgencyLabel(
          l10n?.selectIngredientsExpiringLabel ?? 'Expiring', Colors.orange);
    }
    if (daysToExpiry <= 5) {
      return _UrgencyLabel(l10n?.selectIngredientsSoonLabel ?? 'Soon', Colors.amber);
    }
    return _UrgencyLabel(l10n?.selectIngredientsFreshLabel ?? 'Fresh', Colors.green);
  }

  String _formatQuantity(BuildContext context, double qty, String unit) {
    final l10n = AppLocalizations.of(context);
    final value =
        (qty % 1 == 0) ? qty.toStringAsFixed(0) : qty.toStringAsFixed(1);
    return l10n?.selectIngredientsQuantityLeft(value, unit) ??
        '$value $unit left';
  }
}

class _UrgencyLabel {
  final String label;
  final Color color;

  const _UrgencyLabel(this.label, this.color);
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Icon(icon,
            size: 18,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final Color? dotColor;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = selected
        ? (isDark ? Colors.white : Colors.black)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final bgColor = selected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final textColor = selected
        ? (isDark ? Colors.black : Colors.white)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: baseColor.withValues(alpha: selected ? 0 : 0.2)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (dotColor != null) ...[
                AnimatedScale(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  scale: selected ? 1.08 : 1.0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServingsControl extends StatelessWidget {
  final int servings;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _ServingsControl({
    required this.servings,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          _ServingsButton(icon: Icons.remove, onTap: onDecrement),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$servings',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              Text(
                l10n?.selectIngredientsPeopleShort ?? 'Ppl',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(width: 6),
          _ServingsButton(icon: Icons.add, onTap: onIncrement, accent: true),
        ],
      ),
    );
  }
}

class _ServingsButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  const _ServingsButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppStyle.primary : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 32,
        width: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent
              ? AppStyle.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _StudentToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onToggle;

  const _StudentToggle({required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (enabled)
              Container(
                decoration: BoxDecoration(
                  color: AppStyle.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            Icon(
              Icons.school,
              size: 24,
              color: enabled ? AppStyle.primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _GenerateButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0661E0), Color(0xFF3B82F6)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0661E0).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  l10n?.todayGenerate ?? 'Generate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== Generator Page ==================

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;
  const _InfoPill(
      {required this.icon,
      required this.text,
      required this.bg,
      required this.fg});
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: fg, fontWeight: FontWeight.w600)))
        ]));
  }
}

class _ShimmerRecipeCard extends StatefulWidget {
  const _ShimmerRecipeCard();
  @override
  State<_ShimmerRecipeCard> createState() => _ShimmerRecipeCardState();
}

class _ShimmerRecipeCardState extends State<_ShimmerRecipeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color =
            Color.lerp(Colors.grey[200], Colors.grey[100], _controller.value);
        return Container(
          decoration: BoxDecoration(
              color: AppStyle.cardColor(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppStyle.softShadow(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      color: color)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4)))
                    ]),
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

class _ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  const _ShimmerBlock({required this.width, required this.height});
  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color =
            Color.lerp(Colors.grey[300], Colors.grey[100], _controller.value);
        return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(6)));
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyHint(
      {required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: theme.dividerColor, width: 1, style: BorderStyle.solid)),
        child: Column(children: [
          Icon(icon, color: colors.onSurface.withValues(alpha: 0.35), size: 32),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: colors.onSurface)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.6), fontSize: 13))
        ]));
  }
}

class _GradientPrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;

  const _GradientPrimaryButton({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primary = colors.primary;
    final primaryDark = Color.lerp(primary, Colors.black, 0.18) ?? primary;
    final primaryLight = Color.lerp(primary, Colors.white, 0.25) ?? primary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [primaryDark, primary, primaryLight]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (enabled)
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({required this.title, this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
        decoration: BoxDecoration(
            color: AppStyle.cardColor(context),
            borderRadius: BorderRadius.circular(AppStyle.cardRadius),
            boxShadow: AppStyle.softShadow(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: colors.onSurface)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.6),
                              height: 1.3))
                    ]
                  ])),
          const SizedBox(height: 12),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child)
        ]));
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;
  final Color bgColor;
  final Color? iconColor;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
    this.bgColor = const Color(0xFFF5F7FA),
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final resolvedBg = isDark && bgColor == const Color(0xFFF5F7FA)
        ? theme.cardColor
        : bgColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: resolvedBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (iconColor ?? AppStyle.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? AppStyle.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              onTap == null && !loading
                  ? Icon(Icons.check, color: Colors.green.shade300)
                  : Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
