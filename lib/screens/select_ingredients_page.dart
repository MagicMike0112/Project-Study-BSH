// lib/screens/select_ingredients_page.dart
import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';

/// 从选择页返回给 TodayPage 的结果
class AiCookingSelectionResult {
  final List<FoodItem> selectedInventoryItems;
  final List<String> extraIngredients;
  final bool addExtrasToInventory;

  /// 用户的特殊要求，例如 "vegan, no peanuts, Asian style"
  final String? specialRequest;

  AiCookingSelectionResult({
    required this.selectedInventoryItems,
    required this.extraIngredients,
    required this.addExtrasToInventory,
    this.specialRequest,
  });
}

class SelectIngredientsPage extends StatefulWidget {
  final InventoryRepository repo;

  /// 预选中的“快过期”食材
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
  bool _addExtrasToInventory = false;

  final TextEditingController _extraController = TextEditingController();

  /// 新增：特殊要求（菜系 / 饮食偏好）
  final TextEditingController _specialRequestController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeItems = widget.repo.getActiveItems();

    // 预选中快要过期的
    for (final item in widget.preselectedExpiring) {
      _selectedIds.add(item.id);
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

  void _confirm() {
    final selected = _activeItems
        .where((item) => _selectedIds.contains(item.id))
        .toList();

    final requestText = _specialRequestController.text.trim();
    final special =
        requestText.isEmpty ? null : requestText; // 为空就不传给 API

    Navigator.pop(
      context,
      AiCookingSelectionResult(
        selectedInventoryItems: selected,
        extraIngredients: List.unmodifiable(_extraIngredients),
        addExtrasToInventory: _addExtrasToInventory,
        specialRequest: special,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose ingredients'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'We pre-selected items that are expiring soon.\n'
                    'You can add more from your fridge or type extra ingredients.',
                  ),
                  const SizedBox(height: 16),

                  // ===== From inventory =====
                  const Text(
                    'From your inventory',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_activeItems.isEmpty)
                    const Text(
                      'No items in your inventory yet.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ..._activeItems.map((item) {
                      final selected = _selectedIds.contains(item.id);
                      final days = item.daysToExpiry;
                      final leftText =
                          days >= 999 ? 'no expiry set' : '$days days left';

                      return CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggleSelected(item),
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.quantity} ${item.unit} • $leftText',
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // ===== Extra ingredients =====
                  const Text(
                    'Extra ingredients',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _extraController,
                          decoration: const InputDecoration(
                            hintText: 'Add extra ingredient',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addExtraIngredient(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addExtraIngredient,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _extraIngredients
                        .map(
                          (e) => Chip(
                            label: Text(e),
                            onDeleted: () => _removeExtraIngredient(e),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _addExtrasToInventory,
                        onChanged: (v) =>
                            setState(() => _addExtrasToInventory = v ?? false),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Also add new ingredients to inventory (optional)',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Recommended only for fresh ingredients, not condiments.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ===== 新增：特殊要求 =====
                  const Text(
                    'Special request (optional)',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _specialRequestController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText:
                          'e.g. "vegan", "no peanuts", "Chinese style", "high protein"...',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We will send this to AI together with your ingredients.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // 底部按钮
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Use these ingredients'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
