// lib/screens/inventory_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const Color _backgroundColor = Color(0xFFF8F9FC);

  // 🟢 通用方法：显示强制3秒消失的悬浮通知
  void _showAutoDismissSnackBar(BuildContext context, String message, {VoidCallback? onUndo}) {
    // 1. 清除旧的
    ScaffoldMessenger.of(context).clearSnackBars();
    
    // 2. 显示新的
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // 🟢 使用 fixed+透明背景，让它贴在底部
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        
        // 🟢 自定义气泡内容
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
          // 距离底部 20
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
      try {
        controller.close();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: repo,
      builder: (context, child) {
        final allItems = repo.getActiveItems();

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
            centerTitle: false,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
          body: hasAnyItems
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    FadeInSlide(
                      index: 0,
                      child: _InventoryHeroCard(
                        total: allItems.length,
                        fridge: fridgeItems.length,
                        freezer: freezerItems.length,
                        pantry: pantryItems.length,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (fridgeItems.isNotEmpty) ...[
                      FadeInSlide(
                        index: 1,
                        child: _buildSectionHeader(
                          context,
                          icon: Icons.kitchen_rounded,
                          label: 'Fridge',
                          color: const Color(0xFF005F87),
                          count: fridgeItems.length,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...fridgeItems.asMap().entries.map(
                        (entry) => FadeInSlide(
                          key: ValueKey(entry.value.id),
                          index: 2 + (entry.key > 5 ? 5 : entry.key), 
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildDismissibleItem(context, entry.value, theme),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (freezerItems.isNotEmpty) ...[
                      FadeInSlide(
                        index: 3, 
                        child: _buildSectionHeader(
                          context,
                          icon: Icons.ac_unit_rounded,
                          label: 'Freezer',
                          color: const Color(0xFF3F51B5),
                          count: freezerItems.length,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...freezerItems.asMap().entries.map(
                        (entry) => FadeInSlide(
                          key: ValueKey(entry.value.id),
                          index: 4 + (entry.key > 5 ? 5 : entry.key),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildDismissibleItem(context, entry.value, theme),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (pantryItems.isNotEmpty) ...[
                      FadeInSlide(
                        index: 5,
                        child: _buildSectionHeader(
                          context,
                          icon: Icons.shelves,
                          label: 'Pantry',
                          color: Colors.brown,
                          count: pantryItems.length,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...pantryItems.asMap().entries.map(
                        (entry) => FadeInSlide(
                          key: ValueKey(entry.value.id),
                          index: 6 + (entry.key > 5 ? 5 : entry.key),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildDismissibleItem(context, entry.value, theme),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ],
                )
              : _buildEmptyState(context),
        );
      },
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
      child: FadeInSlide(
        index: 0,
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
        HapticFeedback.mediumImpact();
        
        final deletedItem = item;
        await repo.deleteItem(item.id);
        
        if (!context.mounted) return;
        
        _showAutoDismissSnackBar(
          context,
          'Deleted "${deletedItem.name}"',
          onUndo: () async {
            await repo.addItem(deletedItem);
          },
        );
      },
      child: BouncingButton(
        onTap: () => _openEditPage(context, item),
        onLongPress: () {
          HapticFeedback.selectionClick();
          _showItemActionsSheet(context, item);
        },
        child: _buildItemCard(context, item),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, FoodItem item) {
    final days = item.daysToExpiry;
    final qtyText =
        '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}';

    final daysLabel = days >= 999
        ? 'No Expiry'
        : days == 0
            ? 'Today'
            : days < 0
                ? '${-days}d ago'
                : '${days}d left';

    final urgency = _urgency(days);
    final leading = _leadingIcon(item);
    final bool isLowStock = item.isLowStock; 

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isLowStock ? Border.all(color: Colors.orange.shade300, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
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
                            // 🟢 这里显示“谁买的”标签
                            if (item.ownerName != null) ...[
                              const SizedBox(width: 8),
                              _UserAvatarTag(name: item.ownerName!),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            if (isLowStock) ...[
                                Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                        children: [
                                            Icon(Icons.trending_down_rounded, size: 12, color: Colors.orange),
                                            SizedBox(width: 4),
                                            Text('LOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.deepOrange)),
                                        ],
                                    ),
                                ),
                            ],
                            _expiryPill(context, urgency, daysLabel),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    qtyText,
                    style: TextStyle(
                      fontSize: 13,
                      color: isLowStock ? Colors.deepOrange : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.minQuantity != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                              'Keep > ${item.minQuantity!.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
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
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFD32F2F);
        break;
      case _Urgency.today:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case _Urgency.soon:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        break;
      case _Urgency.ok:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case _Urgency.none:
        bg = const Color(0xFFF5F5F5);
        fg = const Color(0xFF616161);
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
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodPage(
          repo: repo,
          itemToEdit: item,
        ),
      ),
    );
  }

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
                    
                    if (!context.mounted) return;
                    _showAutoDismissSnackBar(
                      context,
                      'Cooked ${usedQty.toStringAsFixed(1)} of ${item.name}',
                      onUndo: () async {
                        await repo.updateItem(oldItem);
                      },
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
                          behavior: SnackBarBehavior.fixed,
                          content: Text('Please make sure the food is safe for your pet!'),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }

                    if (!context.mounted) return;
                    _showAutoDismissSnackBar(
                      context,
                      'Fed ${item.name} to pet',
                      onUndo: () async {
                        await repo.updateItem(oldItem);
                      },
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
                        if (!context.mounted) return;
                        _showAutoDismissSnackBar(
                          context,
                          'Deleted "${deletedItem.name}"',
                          onUndo: () async {
                            await repo.addItem(deletedItem);
                          },
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

    String? selectedChip = 'All'; 
    String? errorText;

    return showDialog<double>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            
            void updateQty(double val, String chipLabel) {
              controller.text = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2);
              setState(() {
                selectedChip = chipLabel;
                errorText = null;
              });
            }

            Widget buildChip(String label, double val) {
              final isSelected = selectedChip == label;
              return ActionChip(
                label: Text(label),
                onPressed: () => updateQty(val, label),
                backgroundColor: isSelected ? const Color(0xFF005F87).withOpacity(0.15) : Colors.grey[100],
                side: BorderSide(
                  color: isSelected ? const Color(0xFF005F87) : Colors.transparent,
                  width: 1.5,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF005F87) : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 12,
                ),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }

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
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildChip('All', item.quantity),
                      buildChip('½', item.quantity / 2),
                      buildChip('¼', item.quantity / 4),
                    ],
                  ),

                  const SizedBox(height: 12),
                  
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
                    onTap: () {
                      if (selectedChip != null) {
                        setState(() {
                          selectedChip = null;
                        });
                      }
                    },
                    onChanged: (val) {
                      if (selectedChip != null) {
                        setState(() {
                          selectedChip = null;
                        });
                      }
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

// ================== Hero Card & Other Components (Unchanged) ==================

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
            Color(0xFF003B66),
            Color(0xFF0E7AA8),
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

class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  const BouncingButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
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
          widget.onTap?.call();
        }
      },
      onTapCancel: () {
        if (widget.enabled) _controller.reverse();
      },
      onLongPress: widget.onLongPress,
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