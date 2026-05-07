import 'package:flutter/material.dart';
import '../utils/app_haptics.dart';
import 'package:flutter/services.dart';
import '../models/meal_plan.dart';
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import './select_ingredients_page.dart';
import '../l10n/app_localizations.dart';

class CookingCalendarPage extends StatefulWidget {
  final InventoryRepository repo;

  const CookingCalendarPage({super.key, required this.repo});

  @override
  State<CookingCalendarPage> createState() => _CookingCalendarPageState();
}

class _CookingCalendarPageState extends State<CookingCalendarPage> {
  late DateTime _weekStart;
  late DateTime _selectedDate;
  static const Color _plannerPrimary = Color(0xFF135BEC);
  static const Color _plannerSurfaceDark = Color(0xFF1A2130);
  static const Color _plannerBackgroundDark = Color(0xFF101622);

  final List<_MealSlot> _dailySlots = const [
    _MealSlot.breakfast,
    _MealSlot.lunch,
    _MealSlot.dinner,
  ];

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
    _selectedDate = DateTime.now();
  }

  static DateTime _startOfWeek(DateTime date) {
    final weekday = date.weekday == DateTime.sunday ? 7 : date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - 1));
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDate = day;
    });
  }

  void _onWeekChanged(DateTime newStart) {
    setState(() {
      _weekStart = newStart;
      // NOTE: legacy comment cleaned.
      final now = DateTime.now();
      if (now.isAfter(_weekStart) && now.isBefore(_weekStart.add(const Duration(days: 7)))) {
        _selectedDate = now;
      } else {
        _selectedDate = _weekStart;
      }
    });
  }

  Future<void> _editMeal(DateTime date, _MealSlot slot) async {
    final l10n = AppLocalizations.of(context);
    final existing = widget.repo.getMealPlan(date, slot.name);
    
    final nameController = TextEditingController(text: existing?.mealName ?? '');
    final missingController = TextEditingController(text: existing?.missingItems.join(', ') ?? '');
    final selectedItemIds = {...?existing?.itemIds};
    String? selectedRecipe = existing?.recipeName;

    // NOTE: legacy comment cleaned.
    String inventoryQuery = '';
    final inventoryItems = widget.repo.getActiveItems();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // NOTE: legacy comment cleaned.
            final primary = Theme.of(context).colorScheme.primary;
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(_slotIcon(slot), color: primary),
                          const SizedBox(width: 8),
                          Text(
                            (l10n?.cookingPlanSlot(_slotLabel(context, slot)) ??
                                'Plan ${_slotLabel(context, slot)}'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                           Text(
                            "${date.month}/${date.day}",
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l10n?.cookingMealNameLabel ?? 'Meal name',
                          hintText: l10n?.cookingMealNameHint ?? 'e.g. Lemon Chicken Bowl',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(l10n?.cookingQuickPickRecipes ?? 'Quick pick from recipes', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _RecipeChip(
                            label: 'Pesto Pasta',
                            selected: selectedRecipe == 'Pesto Pasta',
                            onTap: () => setModalState(() {
                              selectedRecipe = 'Pesto Pasta';
                              if (nameController.text.isEmpty) nameController.text = 'Pesto Pasta';
                            }),
                          ),
                          _RecipeChip(
                            label: 'Miso Salmon',
                            selected: selectedRecipe == 'Miso Salmon',
                            onTap: () => setModalState(() {
                              selectedRecipe = 'Miso Salmon';
                              if (nameController.text.isEmpty) nameController.text = 'Miso Salmon';
                            }),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.bookmark_border, size: 16),
                            label: Text(l10n?.cookingBrowseAll ?? 'Browse All'),
                            onPressed: () {
                               // NOTE: legacy comment cleaned.
                               // NOTE: legacy comment cleaned.
                               // NOTE: legacy comment cleaned.
                               Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RecipeArchivePage(repo: widget.repo)),
                               );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (inventoryItems.isNotEmpty) ...[
                        Text(l10n?.cookingUseFromInventory ?? 'Use from inventory', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            hintText: l10n?.inventorySearchHint ?? 'Search inventory',
                            prefixIcon: const Icon(Icons.search_rounded),
                            isDense: true,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (value) => setModalState(() => inventoryQuery = value.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildInventoryGroups(
                                context,
                                inventoryItems,
                                inventoryQuery,
                                selectedItemIds,
                                setModalState,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      TextField(
                        controller: missingController,
                        decoration: InputDecoration(
                          labelText: l10n?.cookingMissingItemsLabel ?? 'Missing items (add to shopping list)',
                          hintText: l10n?.cookingMissingItemsHint ?? 'e.g. garlic, scallions',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.add_shopping_cart_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(l10n?.cancel ?? 'Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(l10n?.cookingSavePlan ?? 'Save Plan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;

    final missingItems = missingController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (missingItems.isNotEmpty) {
      for (final name in missingItems) {
        // NOTE: legacy comment cleaned.
        await widget.repo.saveShoppingItem(
          ShoppingItem(
            id: const Uuid().v4(),
            name: name,
            category: 'general',
            isChecked: false, // NOTE: legacy comment cleaned.
          ),
        );
      }
    }

    final finalName = nameController.text.trim();
    if (finalName.isEmpty && selectedRecipe == null) {
      await widget.repo.deleteMealPlan(date, slot.name);
    } else {
      await widget.repo.upsertMealPlan(
        date: date,
        slot: slot.name,
        mealName: finalName.isEmpty
            ? (selectedRecipe ?? (l10n?.cookingUntitledMeal ?? 'Untitled meal'))
            : finalName,
        recipeName: selectedRecipe,
        itemIds: selectedItemIds,
        missingItems: missingItems,
      );
    }
    if (missingItems.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              l10n?.cookingAddedItemsToShopping(missingItems.length) ??
                  'Added ${missingItems.length} items to shopping list.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repo,
      builder: (context, child) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final surface = isDark ? _plannerSurfaceDark : Colors.white;
        final background = isDark ? _plannerBackgroundDark : const Color(0xFFF6F6F8);

        return Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            title: Text(
              l10n?.cookingMealPlannerTitle ?? 'Meal Planner',
              style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface, fontSize: 26),
            ),
            backgroundColor: background,
            elevation: 0,
            centerTitle: false,
            systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            actions: [
              IconButton(
                icon: const Icon(Icons.today_rounded),
                tooltip: l10n?.cookingJumpToToday ?? 'Jump to today',
                onPressed: () {
                   setState(() {
                     final now = DateTime.now();
                     _weekStart = _startOfWeek(now);
                     _selectedDate = now;
                   });
                },
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeaderSection(
                  background: background,
                  child: _HorizontalWeekCalendar(
                    weekStart: _weekStart,
                    selectedDate: _selectedDate,
                    onDaySelected: _onDaySelected,
                    onWeekChanged: _onWeekChanged,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _formatDateTitle(_selectedDate),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: colors.onSurface),
                        ),
                      ),
                      if (_getRelativeDay(_selectedDate).isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F8F0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _getRelativeDay(_selectedDate).toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF0F9D58),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final slot = _dailySlots[index];
                      final meal = widget.repo.getMealPlan(_selectedDate, slot.name);
                      return _MealPlannerCard(
                        slot: slot,
                        meal: meal,
                        surface: surface,
                        primary: _plannerPrimary,
                        isDark: isDark,
                        onTap: () => _editMeal(_selectedDate, slot),
                      );
                    },
                    childCount: _dailySlots.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  String _formatDateTitle(DateTime d) {
    final material = MaterialLocalizations.of(context);
    final full = material.formatFullDate(d);
    return '${full[0].toUpperCase()}${full.substring(1)}';
  }

  String _getRelativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    
    if (diff == 0) return "Today";
    if (diff == 1) return "Tomorrow";
    if (diff == -1) return "Yesterday";
    return "";
  }

  List<Widget> _buildInventoryGroups(
    BuildContext context,
    List<FoodItem> items,
    String query,
    Set<String> selectedItemIds,
    void Function(VoidCallback) setModalState,
  ) {
    final l10n = AppLocalizations.of(context);
    final filtered = query.isEmpty
        ? items
        : items.where((item) => item.name.toLowerCase().contains(query)).toList();
    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n?.cookingNoMatches ?? 'No matches',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ),
      ];
    }

    final groups = <StorageLocation, List<FoodItem>>{
      StorageLocation.fridge: [],
      StorageLocation.freezer: [],
      StorageLocation.pantry: [],
    };
    for (final item in filtered) {
      groups[item.location]?.add(item);
    }

    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      if (entry.value.isEmpty) continue;
      widgets.add(_inventoryGroupHeader(entry.key));
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entry.value.map((item) {
            final selected = selectedItemIds.contains(item.id);
            final dotColor = _expiryDotColor(item);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(item.name),
                ],
              ),
              selected: selected,
              onSelected: (value) {
                setModalState(() {
                  if (value) {
                    selectedItemIds.add(item.id);
                  } else {
                    selectedItemIds.remove(item.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _inventoryGroupHeader(StorageLocation location) {
    final l10n = AppLocalizations.of(context);
    IconData icon;
    String label;
    switch (location) {
      case StorageLocation.fridge:
        icon = Icons.kitchen_rounded;
        label = l10n?.foodLocationFridge ?? 'Fridge';
        break;
      case StorageLocation.freezer:
        icon = Icons.ac_unit_rounded;
        label = l10n?.foodLocationFreezer ?? 'Freezer';
        break;
      case StorageLocation.pantry:
        icon = Icons.shelves;
        label = l10n?.foodLocationPantry ?? 'Pantry';
        break;
    }
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 14, color: primary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

Color _expiryDotColor(FoodItem item) {
  final days = item.daysToExpiry;
  if (days >= 999) return const Color(0xFF9E9E9E);
  if (days <= 0) return const Color(0xFFD32F2F);
  if (days <= 3) return const Color(0xFFF9A825);
  return const Color(0xFF43A047);
}

// NOTE: legacy comment cleaned.

class _HorizontalWeekCalendar extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onWeekChanged;

  const _HorizontalWeekCalendar({
    required this.weekStart,
    required this.selectedDate,
    required this.onDaySelected,
    required this.onWeekChanged,
  });

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = _CookingCalendarPageState._plannerPrimary;
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final today = DateTime.now();
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => onWeekChanged(weekStart.subtract(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_left_rounded),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              Text(
                "${days.first.month}/${days.first.day} - ${days.last.month}/${days.last.day}",
                style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              IconButton(
                onPressed: () => onWeekChanged(weekStart.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right_rounded),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
        
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final date = days[index];
              final isSelected = _isSameDay(date, selectedDate);
              final isToday = _isSameDay(date, today);
              final dayLabel = MaterialLocalizations.of(context)
                  .narrowWeekdays[date.weekday % 7];

              return GestureDetector(
                onTap: () {
                   AppHaptics.selection();
                   onDaySelected(date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 68,
                  height: isSelected ? 88 : 82,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary
                        : (isDark ? _CookingCalendarPageState._plannerSurfaceDark : Colors.white),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (isToday ? primary.withValues(alpha: 0.25) : Colors.transparent),
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))]
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.85)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${date.day}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                      if (isSelected || isToday) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MealPlannerCard extends StatelessWidget {
  final _MealSlot slot;
  final MealPlan? meal;
  final VoidCallback onTap;
  final Color surface;
  final Color primary;
  final bool isDark;

  const _MealPlannerCard({
    required this.slot,
    required this.meal,
    required this.onTap,
    required this.surface,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isPlanned = meal != null;
    final slotName = _slotLabel(context, slot);
    final slotColor = _slotAccent(slot);
    final pill = _statusPill(context, meal);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: () {
            AppHaptics.selection();
            onTap();
        },
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: isPlanned ? 128 : 104,
          decoration: BoxDecoration(
            color: isPlanned ? surface : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            border: isPlanned ? null : Border.all(color: theme.dividerColor.withValues(alpha: 0.6), width: 1.6),
            boxShadow: isPlanned
                ? [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06), blurRadius: 18, offset: const Offset(0, 8))]
                : [],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPlanned) ...[
                      Row(
                        children: [
                          Icon(_slotIcon(slot), color: slotColor, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            slotName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.more_horiz, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: slotColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(_slotIcon(slot), color: slotColor, size: 26),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal!.mealName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                pill,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(_slotIcon(slot), color: slotColor, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            slotName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            (l10n?.cookingPlanSlot(slotName.toLowerCase()) ??
                                "Plan ${slotName.toLowerCase()}"),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(BuildContext context, MealPlan? meal) {
    final l10n = AppLocalizations.of(context);
    if (meal == null) return const SizedBox.shrink();
    if (meal.missingItems.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_basket_rounded, size: 14, color: Color(0xFFF57C00)),
            const SizedBox(width: 6),
            Text(
              l10n?.cookingMissingItemsCount(meal.missingItems.length) ??
                  'Missing ${meal.missingItems.length} items',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF57C00)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.kitchen_rounded, size: 14, color: Color(0xFF0F9D58)),
          const SizedBox(width: 6),
          Text(
            l10n?.cookingAllItemsInFridge ?? 'All items in fridge',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F9D58)),
          ),
        ],
      ),
    );
  }
}

class _RecipeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RecipeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final textColor = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: 0.9)
                : Theme.of(context).dividerColor.withValues(alpha: 0.7),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.24),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          style: TextStyle(
            color: textColor,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

enum _MealSlot { breakfast, lunch, dinner }

String _slotLabel(BuildContext context, _MealSlot slot) {
  final l10n = AppLocalizations.of(context);
  switch (slot) {
    case _MealSlot.breakfast:
      return l10n?.cookingSlotBreakfast ?? 'Breakfast';
    case _MealSlot.lunch:
      return l10n?.cookingSlotLunch ?? 'Lunch';
    case _MealSlot.dinner:
      return l10n?.cookingSlotDinner ?? 'Dinner';
  }
}

IconData _slotIcon(_MealSlot slot) {
  switch (slot) {
    case _MealSlot.breakfast: return Icons.bakery_dining_rounded;
    case _MealSlot.lunch: return Icons.ramen_dining_rounded;
    case _MealSlot.dinner: return Icons.local_dining_rounded;
  }
}

Color _slotAccent(_MealSlot slot) {
  switch (slot) {
    case _MealSlot.breakfast:
      return const Color(0xFFF59E0B);
    case _MealSlot.lunch:
      return const Color(0xFFFBBF24);
    case _MealSlot.dinner:
      return const Color(0xFF6366F1);
  }
}

class _HeaderSection extends StatelessWidget {
  final Color background;
  final Widget child;

  const _HeaderSection({required this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: child,
    );
  }
}






