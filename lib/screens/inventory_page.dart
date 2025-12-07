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
    final items = repo.getActiveItems();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
      ),
      body: items.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildDismissibleItem(context, item, theme);
              },
            ),
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

  // ================== UI：单个 item（支持左滑删除） ==================

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
      confirmDismiss: (_) => _confirmDelete(context, item),
      onDismissed: (_) async {
        await repo.deleteItem(item.id);
        onRefresh();
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

  // ================== 长按 bottom sheet：Edit / Cook / Feed / Delete ==================

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
                  final usedQty =
                      await _askQuantityDialog(context, item, 'eat');
                  if (usedQty == null || usedQty <= 0) return;
                  await repo.useItemWithImpact(item, 'eat', usedQty);
                  onRefresh();
                },
              ),
              ListTile(
                leading: const Icon(Icons.pets),
                title: const Text('Feed to pet'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final usedQty =
                      await _askQuantityDialog(context, item, 'pet');
                  if (usedQty == null || usedQty <= 0) return;

                  await repo.useItemWithImpact(item, 'pet', usedQty);

                  // 小屎小远彩蛋 + 安全提示（只在第一次显示）
                  if (!repo.hasShownPetWarning) {
                    await repo.markPetWarningShown();
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '小屎 & 陈归远：谢谢你的晚餐～ 也请确认食材对豚鼠是安全的，若不确定先问问兽医🐹',
                        ),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }

                  onRefresh();
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
                    await repo.deleteItem(item.id);
                    onRefresh();
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

  // 放在 InventoryPage（和 TodayPage，如果有的话）里，替换原来的 _askQuantityDialog

Future<double?> _askQuantityDialog(
  BuildContext context,
  FoodItem item,
  String action,
) async {
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
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity (${item.unit})',
                    hintText:
                        'Available: ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
                    errorText: errorText,
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setState(() => errorText = null);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final raw = double.tryParse(
                        controller.text.replaceAll(',', '.'),
                      ) ??
                      double.nan;

                  // 1. 必须是数字
                  if (raw.isNaN) {
                    setState(() {
                      errorText = '请输入一个数字';
                    });
                    return;
                  }

                  // 2. 要 > 0
                  if (raw <= 0) {
                    setState(() {
                      errorText = '数量需要大于 0';
                    });
                    return;
                  }

                  // 3. 不能超过库存
                  if (raw > item.quantity + 1e-9) {
                    setState(() {
                      errorText =
                          '最多只能使用 ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}';
                    });
                    return;
                  }

                  // 合法，直接返回原始数量（不再 clamp）
                  Navigator.pop(ctx, raw);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    },
  );
}


  // ================== 删除确认弹窗 ==================

  Future<bool> _confirmDelete(BuildContext context, FoodItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete item?'),
          content: Text(
            'Remove "${item.name}" from your inventory?\n'
            'This cannot be undone.',
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
