// lib/screens/shopping_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../repositories/inventory_repository.dart';
import '../widgets/add_by_recipe_sheet.dart'; 
import 'shopping_archive_page.dart';

class ShoppingListPage extends StatefulWidget {
  final InventoryRepository repo;

  const ShoppingListPage({super.key, required this.repo});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final TextEditingController _controller = TextEditingController();
  
  // 智能建议列表
  final List<String> _suggestions = [
    'Milk', 'Eggs', 'Avocado', 'Sourdough', 'Chicken Breast', 
    'Toilet Paper', 'Olive Oil', 'Coffee', 'Greek Yogurt', 'Dark Chocolate'
  ];
  
  void _showAutoDismissSnackBar(String message, {VoidCallback? onUndo}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF323232),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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

  String _guessCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('peanut butter')) return 'pantry';
    if (n.contains('milk') || n.contains('yogurt') || n.contains('cheese') || n.contains('egg')) return 'dairy'; 
    if (n.contains('cat') || n.contains('dog') || n.contains('pet') || n.contains('hay')) return 'pet';
    if (n.contains('paper') || n.contains('tissue') || n.contains('soap') || n.contains('clean')) return 'household';
    if (n.contains('frozen') || n.contains('ice cream') || n.contains('pizza')) return 'frozen';
    if (n.contains('water') || n.contains('juice') || n.contains('coffee') || n.contains('beer')) return 'beverage';
    if (n.contains('bread') || n.contains('cake') || n.contains('flour')) return 'bakery';
    if (n.contains('milk') || n.contains('yogurt') || n.contains('cheese') || n.contains('butter') || n.contains('egg')) return 'dairy';
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

  // 弹出 AI 导入 Sheet
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
    const bg = Color(0xFFF8F9FC);
    const primary = Color(0xFF005F87);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Shopping List', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        actions: [
          IconButton(
            tooltip: 'Purchase History',
            icon: const Icon(Icons.history_rounded, color: Colors.black87),
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
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.repo,
        builder: (context, child) {
          final allItems = widget.repo.getShoppingList();
          final activeItems = allItems.where((i) => !i.isChecked).toList();
          final checkedItems = allItems.where((i) => i.isChecked).toList();

          return Column(
            children: [
              // 顶部建议栏
              if (_suggestions.isNotEmpty)
                FadeInSlide(
                  index: 0,
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
                              backgroundColor: Colors.white,
                              label: Text(sug, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              avatar: const Icon(Icons.add_rounded, size: 16, color: primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              
              Expanded(
                child: allItems.isEmpty
                    ? FadeInSlide(index: 1, child: _buildEmptyState())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 160), // 留出足够空间给底部栏
                        children: [
                          ...activeItems.asMap().entries.map((entry) => FadeInSlide(
                            key: ValueKey(entry.value.id),
                            index: 1 + (entry.key > 5 ? 5 : entry.key),
                            child: _buildDismissibleItem(entry.value),
                          )),
                          
                          if (activeItems.isNotEmpty && checkedItems.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('COMPLETED', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                            ),

                          ...checkedItems.asMap().entries.map((entry) => FadeInSlide(
                            key: ValueKey(entry.value.id),
                            index: 1 + activeItems.length + (entry.key > 5 ? 5 : entry.key),
                            child: _buildDismissibleItem(entry.value),
                          )),
                        ],
                      ),
              ),
            ],
          );
        },
      ),

      // 底部工具栏
      bottomSheet: ListenableBuilder(
        listenable: widget.repo,
        builder: (context, child) {
          final items = widget.repo.getShoppingList();
          final checkedItems = items.where((i) => i.isChecked).toList();

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (checkedItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BouncingButton(
                      onTap: () => _moveCheckedToInventory(context, checkedItems),
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
                            Text('Move ${checkedItems.length} items to Fridge', 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // 输入栏 + AI入口
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _addItem,
                        decoration: InputDecoration(
                          hintText: 'Add item (e.g. Milk)...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: UnconstrainedBox(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: BouncingButton(
                                onTap: () => _addItem(_controller.text),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: primary, shape: BoxShape.circle),
                                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 🪄 AI 导入入口：紧邻确认按钮右侧
                    BouncingButton(
                      onTap: _showAiImportSheet,
                      child: Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2575FC).withOpacity(0.3), 
                              blurRadius: 8, 
                              offset: const Offset(0, 4)
                            )
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildDismissibleItem(ShoppingItem item) {
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
        onToggle: () {
          HapticFeedback.selectionClick();
          widget.repo.toggleShoppingItemStatus(item);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[100]!)),
            child: Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[300]),
          ),
          const SizedBox(height: 24),
          Text('Your list is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Add items manually or use AI Scan.', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
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
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
      ),
      alignment: Alignment.center,
      child: Text(initial, style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}

class _ShoppingTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  const _ShoppingTile({required this.item, required this.onToggle});

  Color _catColor(String c) {
    switch(c) {
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

  IconData _catIcon(String c) {
    switch(c) {
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
    final color = _catColor(item.category);
    final isDone = item.isChecked;

    return BouncingButton(
      onTap: onToggle,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDone ? 0.4 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDone ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
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
                    border: Border.all(color: isDone ? color : Colors.grey[300]!, width: 2),
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
                      child: Icon(_catIcon(item.category), size: 18, color: color),
                    ),
                    if (item.ownerName != null)
                      Positioned(right: -5, bottom: -5, child: _UserAvatarTag(name: item.ownerName!, size: 16)),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: isDone ? Colors.grey : Colors.black87,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
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