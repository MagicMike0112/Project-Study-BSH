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

  // 统一的背景色
  static const Color _backgroundColor = Color(0xFFF8F9FC);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allItems = repo.getActiveItems();

    // 排序逻辑保持不变
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

    final hasAnyItems = fridgeItems.isNotEmpty ||
        freezerItems.isNotEmpty ||
        pantryItems.isNotEmpty;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Inventory',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: false, // 保持左对齐的一致性
      ),
      body: hasAnyItems
          ? ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // 1. Dashboard Hero Card
                _InventoryHeroCard(
                  total: allItems.length,
                  fridge: fridgeItems.length,
                  freezer: freezerItems.length,
                  pantry: pantryItems.length,
                ),
                const SizedBox(height: 24),

                if (fridgeItems.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    icon: Icons.kitchen_rounded,
                    label: 'Fridge',
                    color: const Color(0xFF005F87),
                    count: fridgeItems.length,
                  ),
                  const SizedBox(height: 12),
                  ...fridgeItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDismissibleItem(context, item, theme),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (freezerItems.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    icon: Icons.ac_unit_rounded,
                    label: 'Freezer',
                    color: const Color(0xFF3F51B5), // Indigo
                    count: freezerItems.length,
                  ),
                  const SizedBox(height: 12),
                  ...freezerItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDismissibleItem(context, item, theme),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (pantryItems.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    icon: Icons.shelves, // Material Symbols 风格
                    label: 'Pantry',
                    color: Colors.brown,
                    count: pantryItems.length,
                  ),
                  const SizedBox(height: 12),
                  ...pantryItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDismissibleItem(context, item, theme),
                    ),
                  ),
                  const SizedBox(height: 40), // 底部留白
                ],
              ],
            )
          : _buildEmptyState(context),
    );
  }

  // ================== Components ==================

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required int count,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 32,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your inventory is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add items to your fridge, freezer, or pantry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildDismissibleItem(
    BuildContext context,
    FoodItem item,
    ThemeData theme,
  ) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 28),
      ),
      onDismissed: (_) async {
        final deletedItem = item;

        await repo.deleteItem(item.id);
        onRefresh();

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              // 🔴 修改点：改为 fixed，去掉 margin，它就会乖乖贴在底部 Tab 上方
              behavior: SnackBarBehavior.fixed, 
              backgroundColor: const Color(0xFF323232), // 深灰色背景，看起来更像原生
              duration: const Duration(seconds: 3),
              content: Text(
                'Deleted "${deletedItem.name}"',
                style: const TextStyle(color: Colors.white),
              ),
              action: SnackBarAction(
                label: 'UNDO',
                textColor: const Color(0xFF81D4FA), // 浅蓝色按钮，对比度高
                onPressed: () async {
                  await repo.addItem(deletedItem);
                  onRefresh();
                },
              ),
            ),
          );
      },
      child: _buildItemCard(context, item),
    );
  }

  // ✅ 核心卡片优化：去除冗余线条，强调层级
  Widget _buildItemCard(BuildContext context, FoodItem item) {
    final days = item.daysToExpiry;
    final qtyText =
        '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}';

    // 999d => Expiry not set
    final daysLabel = days >= 999
        ? 'No Expiry'
        : days == 0
            ? 'Today'
            : days < 0
                ? '${-days}d ago'
                : '${days}d left';

    final urgency = _urgency(days);
    final leading = _leadingIcon(item);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openEditPage(context, item),
          onLongPress: () => _showItemActionsSheet(context, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 1. Icon (Squircle shape consistent with AccountPage)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: leading.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(leading.icon, color: leading.color, size: 24),
                ),
                const SizedBox(width: 16),

                // 2. Info Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name & Pill Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _expiryPill(context, urgency, daysLabel),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Quantity
                      Text(
                        qtyText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  _Urgency _urgency(int days) {
    if (days < 0) return _Urgency.expired;
    if (days == 0) return _Urgency.today;
    if (days <= 3) return _Urgency.soon;
    if (days >= 999) return _Urgency.none;
    return _Urgency.ok;
  }

  Widget _expiryPill(BuildContext context, _Urgency u, String text) {
    Color bg;
    Color fg;

    switch (u) {
      case _Urgency.expired:
        bg = const Color(0xFFFFEBEE); // Red 50
        fg = const Color(0xFFD32F2F); // Red 700
        break;
      case _Urgency.today:
        bg = const Color(0xFFFFF3E0); // Orange 50
        fg = const Color(0xFFE65100); // Orange 900
        break;
      case _Urgency.soon:
        bg = const Color(0xFFFFF8E1); // Amber 50
        fg = const Color(0xFFF57F17); // Amber 900
        break;
      case _Urgency.ok:
        bg = const Color(0xFFE8F5E9); // Green 50
        fg = const Color(0xFF2E7D32); // Green 800
        break;
      case _Urgency.none:
        bg = const Color(0xFFF5F5F5); // Grey 100
        fg = const Color(0xFF616161); // Grey 700
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  _Leading _leadingIcon(FoodItem item) {
    switch (item.location) {
      case StorageLocation.fridge:
        return const _Leading(Icons.kitchen_rounded, Color(0xFF005F87));
      case StorageLocation.freezer:
        return const _Leading(Icons.ac_unit_rounded, Color(0xFF3F51B5));
      case StorageLocation.pantry:
        return const _Leading(Icons.shelves, Colors.brown);
    }
  }

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
    onRefresh();
  }

  // ================== Action Sheet ==================

  Future<void> _showItemActionsSheet(BuildContext context, FoodItem item) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text(
                              'Select an action',
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                _SheetTile(
                  icon: Icons.edit_rounded,
                  title: 'Edit item',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEditPage(context, item);
                  },
                ),
                _SheetTile(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Cook with this',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final oldItem = item;
                    final usedQty = await _askQuantityDialog(context, item, 'eat');
                    if (usedQty == null || usedQty <= 0) return;

                    await repo.useItemWithImpact(item, 'eat', usedQty);
                    onRefresh();
                    
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                          content: Text('Cooked ${usedQty.toStringAsFixed(1)} of ${item.name}'),
                          action: SnackBarAction(
                            label: 'UNDO',
                            textColor: Colors.white,
                            onPressed: () async {
                              await repo.updateItem(oldItem);
                              onRefresh();
                            },
                          ),
                        ),
                      );
                  },
                ),
                _SheetTile(
                  icon: Icons.pets_rounded,
                  title: 'Feed to pet',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final oldItem = item;
                    final usedQty = await _askQuantityDialog(context, item, 'pet');
                    if (usedQty == null || usedQty <= 0) return;

                    await repo.useItemWithImpact(item, 'pet', usedQty);

                    if (!repo.hasShownPetWarning) {
                      await repo.markPetWarningShown();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please make sure the food is safe for your pet!'),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }

                    onRefresh();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                          content: Text('Fed ${item.name} to pet'),
                          action: SnackBarAction(
                            label: 'UNDO',
                            textColor: Colors.white,
                            onPressed: () async {
                              await repo.updateItem(oldItem);
                              onRefresh();
                            },
                          ),
                        ),
                      );
                  },
                ),
                const Divider(height: 1),
                _SheetTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete',
                  danger: true,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _confirmDelete(context, item);
                    if (ok) {
                      final deletedItem = item;
                      await repo.deleteItem(item.id);
                      onRefresh();
                       if (!context.mounted) return;
                       ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                            content: Text('Deleted "${deletedItem.name}"'),
                            action: SnackBarAction(
                              label: 'UNDO',
                              textColor: Colors.white,
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
              ],
            ),
          ),
        );
      },
    );
  }

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
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Available: ${item.quantity.toStringAsFixed(1)} ${item.unit}',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Quantity used',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.white,
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
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                FilledButton(
                  onPressed: () {
                    final raw = double.tryParse(controller.text.replaceAll(',', '.')) ?? double.nan;

                    if (raw.isNaN) {
                      setState(() => errorText = 'Enter a valid number');
                      return;
                    }
                    if (raw <= 0) {
                      setState(() => errorText = 'Quantity must be > 0');
                      return;
                    }
                    if (raw > item.quantity + 1e-9) {
                       setState(() => errorText = 'Max available: ${item.quantity}');
                      return;
                    }

                    Navigator.pop(ctx, raw);
                  },
                  child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, FoodItem item) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Delete item?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text('Remove "${item.name}" from your inventory permanently?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ) ?? false;
  }
}

// ================== New Inventory Hero Card ==================

class _InventoryHeroCard extends StatelessWidget {
  final int total;
  final int fridge;
  final int freezer;
  final int pantry;

  const _InventoryHeroCard({
    required this.total,
    required this.fridge,
    required this.freezer,
    required this.pantry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF003B66), // Dark Blue
            Color(0xFF0E7AA8), // BSH Blue
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E7AA8).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -30, top: -40, child: _GlassCircle(size: 140)),
          Positioned(left: -20, bottom: -50, child: _GlassCircle(size: 160)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Top Row: Total Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'items total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Bottom Row: Stats Columns
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(icon: Icons.kitchen_rounded, label: 'Fridge', count: fridge),
                    _VerticalDivider(),
                    _StatColumn(icon: Icons.ac_unit_rounded, label: 'Freezer', count: freezer),
                    _VerticalDivider(),
                    _StatColumn(icon: Icons.shelves, label: 'Pantry', count: pantry),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _StatColumn({required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withOpacity(0.15),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final double size;
  const _GlassCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  const _SheetTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.red : Colors.grey[800]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger ? Colors.red : Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _Leading {
  final IconData icon;
  final Color color;
  const _Leading(this.icon, this.color);
}

enum _Urgency { expired, today, soon, ok, none }