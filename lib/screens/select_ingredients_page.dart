// lib/screens/select_ingredients_page.dart
import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';


/// 用户在“选择食材”页面完成后的结果
class AiCookingSelectionResult {
  /// 用户勾选的库存食材（包含原本快要过期的 + 额外选的）
  final List<FoodItem> selectedInventoryItems;

  /// 用户临时输入的额外食材（不一定在库存里，比如"盐"、"酱油"）
  final List<String> extraIngredients;

  /// 用户是否希望把这些额外食材也加入库存
  final bool addExtrasToInventory;

  AiCookingSelectionResult({
    required this.selectedInventoryItems,
    required this.extraIngredients,
    required this.addExtrasToInventory,
  });
}

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
  late Set<String> _selectedIds;
  final TextEditingController _extraCtrl = TextEditingController();
  final List<String> _extraIngredients = [];
  bool _addExtrasToInventory = false;

  @override
  void initState() {
    super.initState();
    // 默认勾选“即将过期”的食材
    _selectedIds = widget.preselectedExpiring.map((e) => e.id).toSet();
  }

  @override
  void dispose() {
    _extraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.repo.getActiveItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose ingredients'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'We pre-selected items that are expiring soon.\n'
              'You can add more from your fridge or type extra ingredients.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'From your inventory',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ...all.map((item) {
                  final selected = _selectedIds.contains(item.id);
                  final isExpiring = widget.preselectedExpiring
                      .any((e) => e.id == item.id);
                  final subtitle =
                      '${item.quantity} ${item.unit} • ${item.daysToExpiry} days left'
                      '${isExpiring ? ' • expiring' : ''}';

                  return CheckboxListTile(
                    value: selected,
                    title: Text(item.name),
                    subtitle: Text(subtitle),
                    onChanged: (_) {
                      setState(() {
                        if (selected) {
                          _selectedIds.remove(item.id);
                        } else {
                          _selectedIds.add(item.id);
                        }
                      });
                    },
                  );
                }),
                const Divider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Extra ingredients',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _extraCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Add extra ingredient',
                            hintText: 'e.g. 2 eggs, soy sauce',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addExtraIngredient(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addExtraIngredient,
                      ),
                    ],
                  ),
                ),
                if (_extraIngredients.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _extraIngredients
                          .map(
                            (e) => Chip(
                              label: Text(e),
                              onDeleted: () {
                                setState(() {
                                  _extraIngredients.remove(e);
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: CheckboxListTile(
                    title: const Text(
                        'Also add new ingredients to inventory (optional)'),
                    subtitle: const Text(
                      'Recommended only for fresh ingredients, not condiments.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _addExtrasToInventory,
                    onChanged: (v) =>
                        setState(() => _addExtrasToInventory = v ?? false),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  final allItems = widget.repo.getActiveItems();
                  final selectedItems = allItems
                      .where((i) => _selectedIds.contains(i.id))
                      .toList();

                  Navigator.pop(
                    context,
                    AiCookingSelectionResult(
                      selectedInventoryItems: selectedItems,
                      extraIngredients: List.of(_extraIngredients),
                      addExtrasToInventory: _addExtrasToInventory,
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Use these ingredients'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addExtraIngredient() {
    final text = _extraCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _extraIngredients.add(text);
      _extraCtrl.clear();
    });
  }
}
