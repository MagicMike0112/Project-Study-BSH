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
    final bg = const Color(0xFFF6F8FA);

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

    final hasAnyItems = fridgeItems.isNotEmpty ||
        freezerItems.isNotEmpty ||
        pantryItems.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Inventory'),
      ),
      body: hasAnyItems
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                _InventoryHeroCard(
                  total: allItems.length,
                  fridge: fridgeItems.length,
                  freezer: freezerItems.length,
                  pantry: pantryItems.length,
                ),
                const SizedBox(height: 14),

                if (fridgeItems.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.kitchen,
                    label: 'Fridge',
                    color: const Color(0xFF005F87),
                    count: fridgeItems.length,
                  ),
                  const SizedBox(height: 10),
                  ...fridgeItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildDismissibleItem(context, item, theme),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                if (freezerItems.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.ac_unit,
                    label: 'Freezer',
                    color: Colors.indigo,
                    count: freezerItems.length,
                  ),
                  const SizedBox(height: 10),
                  ...freezerItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildDismissibleItem(context, item, theme),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                if (pantryItems.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.inventory_2_outlined,
                    label: 'Pantry',
                    color: Colors.brown,
                    count: pantryItems.length,
                  ),
                  const SizedBox(height: 10),
                  ...pantryItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    required Color color,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.14)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.grey[900],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count items',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  size: 40,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Your inventory is empty',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the + button to add some food.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.25,
                ),
              ),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withOpacity(0.18)),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 26),
      ),
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
      child: _buildItemCard(context, item),
    );
  }

  // ================== ✅ pill 挪到底部提示行 ==================

  Widget _buildItemCard(BuildContext context, FoodItem item) {
    final scheme = Theme.of(context).colorScheme;
    final days = item.daysToExpiry;

    final qtyText =
        '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}';

    final locLabel = _locationLabel(item.location);

    // ✅ 关键改动：999d => Expiry not set
    final daysLabel = days >= 999
        ? 'Expiry not set'
        : days == 0
            ? 'Expires today'
            : days < 0
                ? 'Expired ${-days}d ago'
                : 'Expires in ${days}d';

    final urgency = _urgency(days);
    final leading = _leadingIcon(item);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openEditPage(context, item),
        onLongPress: () => _showItemActionsSheet(context, item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 12,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧 icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: leading.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: leading.color.withOpacity(0.16)),
                ),
                child: Icon(leading.icon, color: leading.color),
              ),
              const SizedBox(width: 12),

              // 中间信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // title
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // qty + location
                    Row(
                      children: [
                        Icon(Icons.scale_outlined,
                            size: 14, color: Colors.grey[700]),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            qtyText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.place_outlined,
                            size: 14, color: Colors.grey[700]),
                        const SizedBox(width: 6),
                        Text(
                          locLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Container(height: 1, color: Colors.black.withOpacity(0.06)),
                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: _expiryPill(context, urgency, daysLabel),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.primary.withOpacity(0.55)),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ 这个目前没被用到，保留不动（你原来就是这样）
  Widget _HintRowWithExpiry({required Widget pill}) {
    return Row(
      children: [
        Flexible(child: pill),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Tap to edit • Long-press for actions',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
    IconData icon;

    switch (u) {
      case _Urgency.expired:
        bg = Colors.red.withOpacity(0.12);
        fg = Colors.redAccent;
        icon = Icons.error_outline;
        break;
      case _Urgency.today:
        bg = Colors.orange.withOpacity(0.14);
        fg = Colors.deepOrange;
        icon = Icons.warning_amber_rounded;
        break;
      case _Urgency.soon:
        bg = Colors.amber.withOpacity(0.18);
        fg = Colors.brown;
        icon = Icons.schedule;
        break;
      case _Urgency.ok:
        bg = Colors.green.withOpacity(0.12);
        fg = Colors.green.shade700;
        icon = Icons.eco;
        break;
      case _Urgency.none:
        bg = Colors.black.withOpacity(0.06);
        fg = Colors.grey.shade700;
        icon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _Leading _leadingIcon(FoodItem item) {
    switch (item.location) {
      case StorageLocation.fridge:
        return const _Leading(Icons.kitchen, Color(0xFF005F87));
      case StorageLocation.freezer:
        return const _Leading(Icons.ac_unit, Colors.indigo);
      case StorageLocation.pantry:
        return const _Leading(Icons.inventory_2_outlined, Colors.brown);
    }
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

  Future<void> _showItemActionsSheet(BuildContext context, FoodItem item) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 10),
                _SheetHeader(itemName: item.name),
                const SizedBox(height: 6),

                _SheetTile(
                  icon: Icons.edit,
                  title: 'Edit item',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEditPage(context, item);
                  },
                ),

                _SheetTile(
                  icon: Icons.restaurant,
                  title: 'Cook with this',
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

                _SheetTile(
                  icon: Icons.pets,
                  title: 'Feed to pet',
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
                            'Please make sure the food is safe for your pet before feeding it.',
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

                _SheetTile(
                  icon: Icons.delete_outline,
                  title: 'Delete from inventory',
                  danger: true,
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
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Available: ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: Colors.white,
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
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final raw =
                    double.tryParse(controller.text.replaceAll(',', '.')) ??
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

  Future<bool> _confirmDelete(BuildContext context, FoodItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Delete item?'),
          content: Text('Remove "${item.name}" from your inventory?'),
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

// ================== 额外 UI 小组件（不影响逻辑） ==================

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
      height: 128,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF003B66), Color(0xFF0A6BA8)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(right: -40, top: -30, child: _GlassCircle(size: 150)),
            Positioned(left: 120, bottom: -60, child: _GlassCircle(size: 180)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Icon(Icons.inventory_2,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your inventory',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$total',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                height: 1.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                'items',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fridge $fridge • Freezer $freezer • Pantry $pantry',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String itemName;
  const _SheetHeader({required this.itemName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.more_horiz, color: Colors.grey[800]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              itemName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ],
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
    final color = danger ? Colors.red : Colors.grey[900]!;
    final iconColor = danger ? Colors.red : Colors.grey[800]!;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (danger ? Colors.red : Colors.black).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color,
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
