// lib/screens/shopping_archive_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/inventory_repository.dart';

class ShoppingArchivePage extends StatelessWidget {
  final InventoryRepository repo;
  final Function(String name, String category) onAddBack;

  const ShoppingArchivePage({
    super.key,
    required this.repo,
    required this.onAddBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Purchase History',
          style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colors.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.onSurface.withOpacity(0.6)),
            tooltip: 'Clear History',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear History?'),
                  content: const Text('This will remove all items from your history.'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        repo.clearHistory(); // 这会触发 notifyListeners
                        Navigator.pop(ctx);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      // 🔴 核心修复：使用 AnimatedBuilder 监听 repo 的变化
      body: AnimatedBuilder(
        animation: repo, // 监听仓库变动
        builder: (context, child) {
          final history = repo.shoppingHistory; // 在 builder 内部获取最新数据

          if (history.isEmpty) {
            return _buildEmptyState(context);
          }

          // 按日期分组逻辑 (移动到 builder 内部以确保实时计算)
          final Map<String, List<ShoppingHistoryItem>> grouped = {};
          for (var item in history) {
            final dateKey = _getDateKey(item.date);
            if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
            grouped[dateKey]!.add(item);
          }
          final sortedKeys = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final dateKey = sortedKeys[index];
              final items = grouped[dateKey]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Text(
                      dateKey,
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ...items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          leading: _historyLeading(context, item),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            item.category,
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.5)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF005F87)),
                            tooltip: 'Add back to list',
                            onPressed: () {
                              onAddBack(item.name, item.category);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item.name} added back!'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating, // 悬浮样式
                                ),
                              );
                            },
                          ),
                        ),
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(itemDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMMM d').format(date);
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu_rounded, size: 64, color: colors.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No history yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.onSurface.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            'Items you verify as bought will appear here.',
            style: TextStyle(color: colors.onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _historyLeading(BuildContext context, ShoppingHistoryItem item) {
    final theme = Theme.of(context);
    final buyerName = repo.resolveUserNameById(item.userId);
    return SizedBox(
      width: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 2,
            child: Icon(Icons.check_circle_outline, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 20),
          ),
          if (buyerName != null && buyerName.isNotEmpty)
            Positioned(
              right: -2,
              bottom: -2,
              child: _UserAvatarBadge(name: buyerName, size: 18),
            ),
        ],
      ),
    );
  }
}

class _UserAvatarBadge extends StatelessWidget {
  final String name;
  final double size;
  const _UserAvatarBadge({required this.name, this.size = 18});

  Color _getNameColor(String name) {
    if (name.isEmpty) return Colors.grey;
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink];
    return colors[name.hashCode.abs() % colors.length].shade400;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getNameColor(name);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
