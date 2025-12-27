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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text(
          'Purchase History',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        backgroundColor: const Color(0xFFF8F9FC),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
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
            return _buildEmptyState();
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
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ...items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                          leading: Icon(Icons.check_circle_outline, color: Colors.grey[300], size: 20),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            item.category,
                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No history yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'Items you verify as bought will appear here.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}