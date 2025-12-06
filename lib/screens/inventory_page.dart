import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import 'add_food_page.dart'; // 引用同目录下的添加页面

class InventoryPage extends StatelessWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;

  const InventoryPage({super.key, required this.repo, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final items = repo.getActiveItems();
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: items.isEmpty
          ? const Center(child: Text("Empty Inventory"))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE3F2FD),
                      child: Icon(Icons.kitchen, color: Color(0xFF005F87)),
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${item.quantity} ${item.unit}'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () async {
                      // 跳转到添加/编辑页面
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddFoodPage(repo: repo, itemToEdit: item),
                        ),
                      );
                      onRefresh();
                    },
                  ),
                );
              },
            ),
    );
  }
}