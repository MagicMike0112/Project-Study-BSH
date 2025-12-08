// lib/screens/inventory_page.dart
import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import 'add_food_page.dart';

class InventoryPage extends StatelessWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;

  const InventoryPage({
    super.key,
    required this.repo,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allItems = repo.getActiveItems();

    // 按剩余天数排序
    List<FoodItem> sortByExpiry(List<FoodItem> list) {
      final copy = [...list];
      copy.sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));
      return copy;
    }

    final fridgeItems = sortByExpiry(
      allItems.where((i) => i.location == StorageLocation.fridge).toList(),
    );
    final freezerItems = sortByExpiry(
      allItems.where((i) => i.location == StorageLocation.freezer).toList(),
    );
    final pantryItems = sortByExpiry(
      allItems.where((i) => i.location == StorageLocation.pantry).toList(),
    );

    final hasAnyItems =
        fridgeItems.isNotEmpty || freezerItems.isNotEmpty || pantryItems.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
      ),
      body: hasAnyItems
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Fridge
                if (fridgeItems.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.kitchen,
                    label: 'Fridge',
                    color: const Color(0xFF005F87),
                    count: fridgeItems.length,
                  ),
                  const SizedBox(height: 8),
                  ...fridgeItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildDismissibleItem(context, item, theme),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Freezer
                if (freezerItems.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.ac_unit,
                    label: 'Freezer',
                    color: Colors.indigo,
                    count: freezerItems.length,
                  ),
                  const SizedBox(height: 8),
                  ...freezerItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildDismissibleItem(context, item, theme),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Pantry
                if (pantryItems.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.inventory_2_outlined,
                    label: 'Pantry',
                    color: Colors.brown,
                    count: pantryItems.length,
                  ),
                  const SizedBox(height: 8),
                  ...pantryItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildDismissibleItem(context, item, theme),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            )
          : _buildEmptyState(context),
    );
  }

  // ================== Section Header ==================

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    required Color color,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const Spacer(),
        Text(
          '$count items',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ================== UI：空状态 ==================

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Your inventory is empty',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add some food.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== UI：单个 item（左滑删除，直接删 + UNDO） ==================

  Widget _buildDismissibleItem(
      BuildContext context, FoodItem item, ThemeData theme) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete, color: Colors.red.shade400, size: 28),
      ),
      // ⚠️ 已去掉 confirmDismiss，左滑直接删除，靠 SnackBar UNDO 兜底
      onDismissed: (_) async {
        final deletedItem = item;

        await repo.deleteItem(item.id);
        onRefresh();

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text('Deleted "${deletedItem.name}".'),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () async {
                  await repo.addItem(deletedItem);
                  onRefresh();
                },
              ),
            ),
          );
      },
      child: _buildItemTile(context, item, theme),
    );
  }

  // ================== UI：ListTile 本体 ==================

  Widget _buildItemTile(
      BuildContext context, FoodItem item, ThemeData theme) {
    final subtitleLines = <String>[];

    // 数量
    subtitleLines.add(
      '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
    );

    // 存放位置 + 剩余天数
    final locLabel = _locationLabel(item.location);
    final days = item.daysToExpiry;
    final daysLabel = days == 0
        ? 'expires today'
        : days < 0
            ? 'expired ${-days}d ago'
            : 'expires in ${days}d';
    subtitleLines.add('$locLabel · $daysLabel');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openEditPage(context, item),
      onLongPress: () => _showItemActionsSheet(context, item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: Colors.grey.shade50,
          leading: _buildLeadingIcon(item),
          title: Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitleLines.join('\n'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.3,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(FoodItem item) {
    IconData icon;
    Color color;

    switch (item.location) {
      case StorageLocation.fridge:
        icon = Icons.kitchen;
        color = const Color(0xFF005F87);
        break;
      case StorageLocation.freezer:
        icon = Icons.ac_unit;
        color = Colors.indigo;
        break;
      case StorageLocation.pantry:
        icon = Icons.inventory_2_outlined;
        color = Colors.brown;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }

  String _locationLabel(StorageLocation loc) {
    switch (loc) {
      case StorageLocation.fridge:
        return 'Fridge';
      case StorageLocation.freezer:
        return 'Freezer';
      case StorageLocation.pantry:
        return 'Pantry';
    }
  }

  // ================== 跳转到编辑页（里面有删除按钮） ==================

  Future<void> _openEditPage(BuildContext context, FoodItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodPage(
          repo: repo,
          itemToEdit: item,
        ),
      ),
    );

    // 从编辑页返回后刷新 Today / Impact / Inventory
    onRefresh();
  }

  // ================== 长按 bottom sheet：Edit / Cook / Feed / Delete（都带 Undo） ==================

  Future<void> _showItemActionsSheet(
      BuildContext context, FoodItem item) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit item'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openEditPage(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant),
                title: const Text('Cook with this'),
                onTap: () async {
                  Navigator.pop(ctx);

                  final oldItem = item;

                  final usedQty =
                      await _askQuantityDialog(context, item, 'eat');
                  if (usedQty == null || usedQty <= 0) return;

                  await repo.useItemWithImpact(item, 'eat', usedQty);
                  onRefresh();

                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 3),
                        content: Text(
                          'Cooked ${usedQty.toStringAsFixed(usedQty == usedQty.roundToDouble() ? 0 : 1)} ${item.unit} of "${item.name}".',
                        ),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () async {
                            await repo.updateItem(oldItem);
                            onRefresh();
                          },
                        ),
                      ),
                    );
                },
              ),
              ListTile(
                leading: const Icon(Icons.pets),
                title: const Text('Feed to pet'),
                onTap: () async {
                  Navigator.pop(ctx);

                  final oldItem = item;

                  final usedQty =
                      await _askQuantityDialog(context, item, 'pet');
                  if (usedQty == null || usedQty <= 0) return;

                  await repo.useItemWithImpact(item, 'pet', usedQty);

                  if (!repo.hasShownPetWarning) {
                    await repo.markPetWarningShown();
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Shi & Yuan: Thanks for dinner! Please make sure the food is safe for guinea pigs. If you’re not sure, ask a vet first 🐹',
                        ),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }

                  onRefresh();

                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 3),
                        content: Text(
                          'Fed ${usedQty.toStringAsFixed(usedQty == usedQty.roundToDouble() ? 0 : 1)} ${item.unit} of "${item.name}" to your pet.',
                        ),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () async {
                            await repo.updateItem(oldItem);
                            onRefresh();
                          },
                        ),
                      ),
                    );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete from inventory',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await _confirmDelete(context, item);
                  if (ok) {
                    final deletedItem = item;
                    await repo.deleteItem(item.id);
                    onRefresh();

                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 3),
                          content: Text('Deleted "${deletedItem.name}".'),
                          action: SnackBarAction(
                            label: 'UNDO',
                            onPressed: () async {
                              await repo.addItem(deletedItem);
                              onRefresh();
                            },
                          ),
                        ),
                      );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ================== “这次用多少”弹窗 ==================

  Future<double?> _askQuantityDialog(
    BuildContext context,
    FoodItem item,
    String action,
  ) async {
    final theme = Theme.of(context);

    final controller = TextEditingController(
      text: item.quantity.toStringAsFixed(
        item.quantity == item.quantity.roundToDouble() ? 0 : 1,
      ),
    );

    final title =
        action == 'eat' ? 'How much did you cook?' : 'How much did you feed?';

    String? errorText;

    return showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Available: ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Used quantity (${item.unit})',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    errorText = null;
                  }
                },
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final raw = double.tryParse(
                      controller.text.replaceAll(',', '.'),
                    ) ??


                    double.nan;

                if (raw.isNaN) {
                  errorText = '请输入一个数字';
                  (ctx as Element).markNeedsBuild();
                  return;
                }

                if (raw <= 0) {
                  errorText = '数量需要大于 0';
                  (ctx as Element).markNeedsBuild();
                  return;
                }

                if (raw > item.quantity + 1e-9) {
                  errorText =
                      '最多只能使用 ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}';
                  (ctx as Element).markNeedsBuild();
                  return;
                }

                Navigator.pop(ctx, raw);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ================== 删除确认弹窗（只给长按菜单用） ==================

  Future<bool> _confirmDelete(BuildContext context, FoodItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete item?'),
          content: Text(
            'Remove "${item.name}" from your inventory?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
