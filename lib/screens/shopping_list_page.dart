// lib/screens/shopping_list_page.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import 'shopping_archive_page.dart'; // ✅ 确保引入了 Archive 页面

class ShoppingItem {
  final String id;
  final String name;
  final String category; // 'dairy', 'produce', 'meat', 'general'
  bool isChecked;

  ShoppingItem({
    required this.id,
    required this.name,
    this.category = 'general',
    this.isChecked = false,
  });
}

class ShoppingListPage extends StatefulWidget {
  final InventoryRepository repo;

  const ShoppingListPage({super.key, required this.repo});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final TextEditingController _controller = TextEditingController();
  final List<ShoppingItem> _items = [];
  final List<String> _suggestions = ['Eggs', 'Milk', 'Bread', 'Bananas', 'Onions'];

  void _addItem(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      _items.add(ShoppingItem(
        id: const Uuid().v4(),
        name: name.trim(),
        category: _guessCategory(name),
      ));
      _controller.clear();
    });
  }

  String _guessCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('milk') || n.contains('cheese') || n.contains('yogurt') || n.contains('butter')) return 'dairy';
    if (n.contains('apple') || n.contains('banana') || n.contains('carrot') || n.contains('spinach') || n.contains('onion')) return 'produce';
    if (n.contains('chicken') || n.contains('beef') || n.contains('pork') || n.contains('fish')) return 'meat';
    if (n.contains('bread') || n.contains('rice') || n.contains('pasta')) return 'pantry';
    return 'general';
  }

  Future<void> _moveCheckedToInventory(BuildContext context) async {
    final checked = _items.where((i) => i.isChecked).toList();
    if (checked.isEmpty) return;

    // 1. 归档到历史记录
    await widget.repo.archiveShoppingItems(checked);

    // 2. 移动到库存
    for (var item in checked) {
      StorageLocation loc = StorageLocation.fridge; // 默认
      if (item.category == 'pantry') loc = StorageLocation.pantry;
      if (item.category == 'meat') loc = StorageLocation.freezer;

      final newItem = FoodItem(
        id: const Uuid().v4(),
        name: item.name,
        location: loc,
        quantity: 1,
        unit: 'pcs',
        purchasedDate: DateTime.now(),
        category: item.category,
      );
      
      await widget.repo.addItem(newItem);
    }

    setState(() {
      _items.removeWhere((i) => i.isChecked);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          backgroundColor: const Color(0xFF005F87),
          content: Text('${checked.length} items moved to Inventory! 🧊'),
          action: SnackBarAction(label: 'UNDO', textColor: Colors.white, onPressed: () {}),
        ),
      );
    }
  }

  void _clearChecked() {
    setState(() {
      _items.removeWhere((i) => i.isChecked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeItems = _items.where((i) => !i.isChecked).toList();
    final checkedItems = _items.where((i) => i.isChecked).toList();
    const bg = Color(0xFFF8F9FC);
    const primary = Color(0xFF005F87);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'Shopping List',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        actions: [
          // 🆕 历史记录入口
          IconButton(
            tooltip: 'Purchase History',
            icon: const Icon(Icons.history_rounded, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShoppingArchivePage(
                    repo: widget.repo,
                    // 回调：从历史加回清单
                    onAddBack: (name, category) {
                      _addItem(name);
                    },
                  ),
                ),
              );
            },
          ),
          
          // 清空按钮 (仅当有勾选时显示)
          if (checkedItems.isNotEmpty)
            IconButton(
              tooltip: 'Clear checked items',
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.black54),
              onPressed: _clearChecked,
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Smart Suggestions
          if (_suggestions.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (ctx, i) {
                  final sug = _suggestions[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      elevation: 0,
                      side: BorderSide(color: primary.withOpacity(0.1)),
                      backgroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      label: Text(sug, style: const TextStyle(fontSize: 13)),
                      avatar: Icon(Icons.add, size: 16, color: primary),
                      onPressed: () {
                        _addItem(sug);
                        setState(() => _suggestions.removeAt(i));
                      },
                    ),
                  );
                },
              ),
            ),
          
          // 2. List
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      ...activeItems.map((item) => _ShoppingTile(
                        item: item,
                        onToggle: () => setState(() => item.isChecked = !item.isChecked),
                      )),
                      
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

                      ...checkedItems.map((item) => _ShoppingTile(
                        item: item,
                        onToggle: () => setState(() => item.isChecked = !item.isChecked),
                      )),
                    ],
                  ),
          ),
        ],
      ),

      // 3. Bottom Input Area
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (checkedItems.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _moveCheckedToInventory(context),
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: Text('Move ${checkedItems.length} items to Fridge'),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _addItem,
                    decoration: InputDecoration(
                      hintText: 'Add item (e.g. Milk)...',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          Text(
            'Your list is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add suggestions above or type your own.',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _ShoppingTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;

  const _ShoppingTile({required this.item, required this.onToggle});

  Color _catColor(String c) {
    switch(c) {
      case 'dairy': return Colors.blue;
      case 'produce': return Colors.green;
      case 'meat': return Colors.red;
      case 'pantry': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _catIcon(String c) {
    switch(c) {
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

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDone ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
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
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDone ? Colors.grey[600] : Colors.black87,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}