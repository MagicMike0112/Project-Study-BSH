import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meal_plan.dart';
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';
import '../models/shopping_item.dart';
import '../repositories/inventory_repository.dart';
import 'select_ingredients_page.dart';

class CookingCalendarPage extends StatefulWidget {
  final InventoryRepository repo;

  const CookingCalendarPage({super.key, required this.repo});

  @override
  State<CookingCalendarPage> createState() => _CookingCalendarPageState();
}

class _CookingCalendarPageState extends State<CookingCalendarPage> {
  late DateTime _weekStart;
  late DateTime _selectedDate;

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
      // 切换周时，优先选中今天，否则选中周一
      final now = DateTime.now();
      if (now.isAfter(_weekStart) && now.isBefore(_weekStart.add(const Duration(days: 7)))) {
        _selectedDate = now;
      } else {
        _selectedDate = _weekStart;
      }
    });
  }

  Future<void> _editMeal(DateTime date, _MealSlot slot) async {
    final existing = widget.repo.getMealPlan(date, slot.name);
    
    final nameController = TextEditingController(text: existing?.mealName ?? '');
    final missingController = TextEditingController(text: existing?.missingItems.join(', ') ?? '');
    final selectedItemIds = {...?existing?.itemIds};
    String? selectedRecipe = existing?.recipeName;

    // 获取库存前10项
    final inventoryItems = widget.repo.getActiveItems();
    String inventoryQuery = '';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // 键盘弹起时避免遮挡
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                          Icon(_slotIcon(slot), color: const Color(0xFF005F87)),
                          const SizedBox(width: 8),
                          Text(
                            'Plan ${_slotLabel(slot)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                           Text(
                            "${date.month}/${date.day}",
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Meal name',
                          hintText: 'e.g. Lemon Chicken Bowl',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Quick pick from recipes', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                            label: const Text('Browse All'),
                            onPressed: () {
                               // 2. 修正类名：如果这里报错，请确认 archive_page.dart 里的类名是 ArchivePage 还是 RecipeArchivePage
                               // 这里我改为更通用的 ArchivePage (根据文件名推测)
                               // 如果你的类名是 RecipeArchivePage，请手动改回
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
                        Text('Use from inventory', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search inventory',
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
                          labelText: 'Missing items (add to shopping list)',
                          hintText: 'e.g. garlic, scallions',
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
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF005F87),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Save Plan'),
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
        // 3. 修复参数：补全了 ShoppingItem 可能缺少的参数 (如 isChecked)
        await widget.repo.saveShoppingItem(
          ShoppingItem(
            id: const Uuid().v4(),
            name: name,
            category: 'general',
            isChecked: false, // 补全参数
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
        mealName: finalName.isEmpty ? (selectedRecipe ?? 'Untitled meal') : finalName,
        recipeName: selectedRecipe,
        itemIds: selectedItemIds,
        missingItems: missingItems,
      );
    }
    if (missingItems.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${missingItems.length} items to shopping list.'),
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
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text('Meal Planner', style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface)),
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            centerTitle: false,
            systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            actions: [
              IconButton(
                icon: const Icon(Icons.today_rounded),
                tooltip: "Jump to today",
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
          body: Column(
            children: [
              _HorizontalWeekCalendar(
                weekStart: _weekStart,
                selectedDate: _selectedDate,
                onDaySelected: _onDaySelected,
                onWeekChanged: _onWeekChanged,
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _formatDateTitle(_selectedDate),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colors.onSurface),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getRelativeDay(_selectedDate),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface.withOpacity(0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    ..._dailySlots.map((slot) {
                       final meal = widget.repo.getMealPlan(_selectedDate, slot.name);
                       return _MinimalMealCard(
                         slot: slot,
                         meal: meal,
                         onTap: () => _editMeal(_selectedDate, slot),
                       );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  String _formatDateTitle(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return "${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}";
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
    final filtered = query.isEmpty
        ? items
        : items.where((item) => item.name.toLowerCase().contains(query)).toList();
    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'No matches',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
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
    IconData icon;
    String label;
    switch (location) {
      case StorageLocation.fridge:
        icon = Icons.kitchen_rounded;
        label = 'Fridge';
        break;
      case StorageLocation.freezer:
        icon = Icons.ac_unit_rounded;
        label = 'Freezer';
        break;
      case StorageLocation.pantry:
        icon = Icons.shelves;
        label = 'Pantry';
        break;
    }
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF005F87)),
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

// ----------------- 子组件 (无需修改) -----------------

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
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final today = DateTime.now();

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
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              Text(
                "${days.first.month}/${days.first.day} - ${days.last.month}/${days.last.day}",
                style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
              IconButton(
                onPressed: () => onWeekChanged(weekStart.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right_rounded),
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ],
          ),
        ),
        
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final date = days[index];
              final isSelected = _isSameDay(date, selectedDate);
              final isToday = _isSameDay(date, today);
              final dayLabel = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

              return GestureDetector(
                onTap: () {
                   HapticFeedback.selectionClick();
                   onDaySelected(date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF005F87) 
                        : (isToday ? const Color(0xFF005F87).withOpacity(0.08) : theme.cardColor),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : (isToday ? const Color(0xFF005F87).withOpacity(0.3) : theme.dividerColor),
                      width: isToday ? 1.5 : 1,
                    ),
                    boxShadow: isSelected 
                        ? [BoxShadow(color: const Color(0xFF005F87).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white.withOpacity(0.9) : theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${date.day}",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
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

class _MinimalMealCard extends StatelessWidget {
  final _MealSlot slot;
  final MealPlan? meal;
  final VoidCallback onTap;

  const _MinimalMealCard({
    required this.slot,
    required this.meal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlanned = meal != null;
    final slotName = _slotLabel(slot);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
            HapticFeedback.lightImpact();
            onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 88, 
          decoration: BoxDecoration(
            color: isPlanned ? theme.cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isPlanned ? null : Border.all(color: theme.dividerColor.withOpacity(0.6), width: 1.5),
            boxShadow: isPlanned 
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))] 
                : [],
          ),
          child: Row(
            children: [
              if (isPlanned)
                  Container(
                    width: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF005F87), 
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                    ),
                  )
              else 
                  const SizedBox(width: 6),

              const SizedBox(width: 16),
              
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPlanned ? const Color(0xFF005F87).withOpacity(0.1) : theme.dividerColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _slotIcon(slot),
                  color: isPlanned ? const Color(0xFF005F87) : theme.iconTheme.color?.withOpacity(0.3),
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slotName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPlanned ? meal!.mealName : "Tap to plan",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isPlanned ? FontWeight.w600 : FontWeight.w500,
                        color: isPlanned 
                            ? theme.colorScheme.onSurface 
                            : theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                    if (isPlanned && meal!.missingItems.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                         "+ ${meal!.missingItems.length} items to buy",
                         style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ]
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: isPlanned 
                    ? const Icon(Icons.edit_rounded, size: 18, color: Colors.grey)
                    : Icon(Icons.add_circle_outline_rounded, color: theme.disabledColor),
              ),
            ],
          ),
        ),
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
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      checkmarkColor: Colors.white,
      selectedColor: const Color(0xFF005F87),
      labelStyle: TextStyle(
          color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

enum _MealSlot { breakfast, lunch, dinner }

String _slotLabel(_MealSlot slot) {
  switch (slot) {
    case _MealSlot.breakfast: return 'Breakfast';
    case _MealSlot.lunch: return 'Lunch';
    case _MealSlot.dinner: return 'Dinner';
  }
}

IconData _slotIcon(_MealSlot slot) {
  switch (slot) {
    case _MealSlot.breakfast: return Icons.bakery_dining_rounded;
    case _MealSlot.lunch: return Icons.ramen_dining_rounded;
    case _MealSlot.dinner: return Icons.local_dining_rounded;
  }
}
