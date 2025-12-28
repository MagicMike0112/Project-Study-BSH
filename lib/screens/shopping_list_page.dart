// lib/screens/shopping_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../repositories/inventory_repository.dart';
import 'shopping_archive_page.dart';

class ShoppingListPage extends StatefulWidget {
  final InventoryRepository repo;

  const ShoppingListPage({super.key, required this.repo});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _suggestions = ['Eggs', 'Milk', 'Bread', 'Bananas', 'Timothy Hay', 'Romaine Lettuce', 'Bell Pepper'];
  
  // 🟢 修复版：使用透明背景+Fixed模式，强制让气泡停在底部
  void _showAutoDismissSnackBar(String message, {VoidCallback? onUndo}) {
    if (!mounted) return;

    // 1. 清除旧的
    ScaffoldMessenger.of(context).clearSnackBars();
    
    // 2. 显示新的
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // 🟢 关键修改1：使用 fixed，这样它会像地板一样贴在最下面，不会乱飘
        behavior: SnackBarBehavior.fixed,
        // 🟢 关键修改2：背景透明，阴影去掉
        backgroundColor: Colors.transparent,
        elevation: 0,
        // 系统可能忽略 duration，所以需要手动关闭逻辑
        duration: const Duration(seconds: 3),
        
        // 🟢 关键修改3：内容本身就是一个“悬浮气泡”
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
          // 🟢 修改点：将底部边距改为 20，让它停靠在屏幕最底部
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

    // 3. 强制关闭逻辑
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        try {
          controller.close();
        } catch (_) {}
      }
    });
  }

  @override
  void initState() {
    super.initState();
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
    if (n.contains('hay') || n.contains('pellet') || n.contains('guinea') || n.contains('lettuce') || n.contains('pepper')) return 'pet';
    if (n.contains('milk') || n.contains('cheese') || n.contains('yogurt') || n.contains('butter')) return 'dairy';
    if (n.contains('apple') || n.contains('banana') || n.contains('carrot') || n.contains('spinach') || n.contains('onion')) return 'produce';
    if (n.contains('chicken') || n.contains('beef') || n.contains('fish')) return 'meat';
    if (n.contains('bread') || n.contains('rice') || n.contains('pasta')) return 'pantry';
    return 'general';
  }

  Future<void> _moveCheckedToInventory(BuildContext context, List<ShoppingItem> checkedItems) async {
    HapticFeedback.mediumImpact();

    await widget.repo.checkoutShoppingItems(checkedItems);

    if (context.mounted) {
      _showAutoDismissSnackBar('${checkedItems.length} items moved to Inventory! 🧊');
    }
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
      // 使用 ListenableBuilder 监听 Repo
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
                              label: Text(sug, style: const TextStyle(fontSize: 13)),
                              avatar: Icon(Icons.add, size: 16, color: primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: primary.withOpacity(0.1)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              
              // 列表区域
              Expanded(
                child: allItems.isEmpty
                    ? FadeInSlide(index: 1, child: _buildEmptyState())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        children: [
                          // 未完成项
                          ...activeItems.asMap().entries.map((entry) => FadeInSlide(
                            key: ValueKey(entry.value.id),
                            index: 1 + (entry.key > 5 ? 5 : entry.key),
                            child: _buildDismissibleItem(entry.value),
                          )),
                          
                          // 分割线
                          if (activeItems.isNotEmpty && checkedItems.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('Completed', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                            ),

                          // 已完成项
                          ...checkedItems.asMap().entries.map((entry) => FadeInSlide(
                            key: ValueKey(entry.value.id),
                            index: 1 + activeItems.length + (entry.key > 5 ? 5 : entry.key),
                            child: _buildDismissibleItem(entry.value),
                          )),
                          
                          // 底部留白给 BottomSheet
                          if (checkedItems.isNotEmpty) const SizedBox(height: 80), 
                        ],
                      ),
              ),
            ],
          );
        },
      ),

      // 底部输入框和结算按钮
      bottomSheet: ListenableBuilder(
        listenable: widget.repo,
        builder: (context, child) {
          final items = widget.repo.getShoppingList();
          final checkedItems = items.where((i) => i.isChecked).toList();

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (checkedItems.isNotEmpty) ...[
                  BouncingButton(
                    onTap: () => _moveCheckedToInventory(context, checkedItems),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_rounded, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('Move ${checkedItems.length} items to Fridge', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addItem,
                  decoration: InputDecoration(
                    hintText: 'Add item (e.g. Milk)...',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded),
                      color: primary,
                      onPressed: () => _addItem(_controller.text),
                    ),
                  ),
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
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 28),
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
          Icon(Icons.shopping_cart_checkout_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Your list is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text('Add suggestions above or type your own.', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// 🟢 新增：用户头像标签组件
class _UserAvatarTag extends StatelessWidget {
  final String name;
  const _UserAvatarTag({required this.name});

  Color _getNameColor(String name) {
    if (name.isEmpty) return Colors.grey;
    final colors = [
      Colors.blue.shade600,
      Colors.red.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _getNameColor(name);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ================== Helper Widgets ==================

class _ShoppingTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;

  const _ShoppingTile({required this.item, required this.onToggle});

  Color _catColor(String c) {
    switch(c) {
      case 'pet': return Colors.brown;
      case 'dairy': return Colors.blue;
      case 'produce': return Colors.green;
      case 'meat': return Colors.red;
      case 'pantry': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _catIcon(String c) {
    switch(c) {
      case 'pet': return Icons.pets;
      case 'dairy': return Icons.local_drink_rounded;
      case 'produce': return Icons.eco_rounded;
      case 'meat': return Icons.restaurant_rounded;
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
        opacity: isDone ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDone ? [] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDone ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDone ? color : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: isDone 
                    ? const Icon(Icons.check, size: 16, color: Colors.white) 
                    : null,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_catIcon(item.category), size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDone ? Colors.grey[600] : Colors.black87,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: color,
                        ),
                      ),
                      // 这里显示“谁买的”标签
                      if (item.ownerName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _UserAvatarTag(name: item.ownerName!),
                            const SizedBox(width: 4),
                            Text(
                              item.ownerName!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
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