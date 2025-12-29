// lib/widgets/food_card.dart
import 'package:flutter/material.dart';
import '../models/food_item.dart';

class FoodCard extends StatelessWidget {
  final FoodItem item;
  final Function(String action) onAction; // 回调函数

  /// ✅ 可选：允许外部传入 leading（用于 TodayPage 与 InventoryPage 统一图标风格）
  /// 不传则保持你原来的 CircleAvatar(timer) 逻辑不变。
  final Widget? leading;

  const FoodCard({
    super.key,
    required this.item,
    required this.onAction,
    this.leading,
  });

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

  @override
  Widget build(BuildContext context) {
    final isCritical = item.daysToExpiry <= 1;
    final scheme = Theme.of(context).colorScheme;

    final bgColor = isCritical
        ? scheme.errorContainer.withOpacity(0.15)
        : scheme.primaryContainer.withOpacity(0.15);
    final iconColor = isCritical ? scheme.error : scheme.primary;

    return Card(
      elevation: 0,
      child: ListTile(
        // ✅ 如果传了 leading 就用传入的；否则维持原样（不动其它逻辑）
        leading: leading ??
            CircleAvatar(
              backgroundColor: bgColor,
              child: Icon(Icons.timer, color: iconColor),
            ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${item.daysToExpiry} days left • ${_locationLabel(item.location)}',
        ),
        trailing: PopupMenuButton(
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: 'eat',
              child: Row(
                children: [
                  Icon(Icons.restaurant, size: 18),
                  SizedBox(width: 8),
                  Text('Cook / Eat'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pet',
              child: Row(
                children: [
                  Icon(Icons.pets, size: 18),
                  SizedBox(width: 8),
                  Text('Feed Pets'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'trash',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18),
                  SizedBox(width: 8),
                  Text('Discard'),
                ],
              ),
            ),
          ],
          onSelected: (val) {
            onAction(val);
            if (val == 'pet') {
              // 你的专属彩蛋 🐹
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Little Shi & Little Yuan are happy! 🐹'),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
