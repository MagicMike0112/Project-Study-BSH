// lib/screens/shopping_archive_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/inventory_repository.dart';

class ShoppingArchivePage extends StatelessWidget {
  final InventoryRepository repo;
  // 回调：当用户想把历史物品加回清单时调用
  final Function(String name, String category) onAddBack;

  const ShoppingArchivePage({
    super.key,
    required this.repo,
    required this.onAddBack,
  });

  @override
  Widget build(BuildContext context) {
    final history = repo.shoppingHistory;

    // 按日期分组数据
    final Map<String, List<ShoppingHistoryItem>> grouped = {};
    for (var item in history) {
      final dateKey = _getDateKey(item.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(item);
    }

    final sortedKeys = grouped.keys.toList(); // 已经是倒序了，因为源数据排过序

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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () {
              // 简单的清空逻辑
               showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear History?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(onPressed: () {
                      repo.clearHistory();
                      Navigator.pop(ctx);
                    }, child: const Text('Clear')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: history.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
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
                    ...items.map((item) => _HistoryItemTile(
                          item: item,
                          onAddBack: () {
                            onAddBack(item.name, item.category);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${item.name} added to list!'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        )),
                    const SizedBox(height: 8),
                  ],
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
    return DateFormat('MMMM d, y').format(date);
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

class _HistoryItemTile extends StatelessWidget {
  final ShoppingHistoryItem item;
  final VoidCallback onAddBack;

  const _HistoryItemTile({required this.item, required this.onAddBack});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(Icons.check_circle_outline, color: Colors.grey[300]),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          item.category,
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF005F87)),
          tooltip: 'Add back to list',
          onPressed: onAddBack,
        ),
      ),
    );
  }
}