// lib/screens/today_page.dart
import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../widgets/food_card.dart';
import 'select_ingredients_page.dart';

class TodayPage extends StatelessWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;

  const TodayPage({
    super.key,
    required this.repo,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final expiring = repo.getExpiringItems(3);

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Food Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildImpactSummary(context),
          const SizedBox(height: 24),

          // Cook with AI 按钮：一直显示
          _buildAiButton(
            onTap: () => _showAiRecipeFlow(context, expiring),
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expiring Soon',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${expiring.length} items',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (expiring.isEmpty)
            _buildEmptyState()
          else
            ...expiring.map(
              (item) => FoodCard(
                item: item,
                onAction: (action) async {
                  // 0) 备份旧状态，方便 UNDO
                  final oldStatus = item.status;

                  // 1) 记录 impact（钱 / CO₂ / 宠物）
                  await repo.recordImpactForAction(item, action);

                  // 2) 更新库存状态
                  FoodStatus? newStatus;
                  if (action == 'eat' || action == 'pet') {
                    newStatus = FoodStatus.consumed;
                  } else if (action == 'trash') {
                    newStatus = FoodStatus.discarded;
                  }

                  if (newStatus != null) {
                    await repo.updateStatus(item.id, newStatus);
                  }

                  // 3) 第一次喂宠物的安全提示
                  if (action == 'pet' && !repo.hasShownPetWarning) {
                    await repo.markPetWarningShown();
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '请只喂适合宠物食用的食材，若不确定请先咨询兽医🐹',
                        ),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }

                  // 4) 提供 3 秒 UNDO
                  if (newStatus != null) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 3),
                          content: Text(
                            _undoLabelForAction(action, item.name),
                          ),
                          action: SnackBarAction(
                            label: 'UNDO',
                            onPressed: () async {
                              // 撤回：把状态改回去
                              await repo.updateStatus(item.id, oldStatus);
                              onRefresh();
                            },
                          ),
                        ),
                      );
                  }

                  onRefresh();
                },
              ),
            ),
        ],
      ),
    );
  }

  // ================== AI Flow 入口 ==================

  Future<void> _showAiRecipeFlow(
    BuildContext context,
    List<FoodItem> expiringItems,
  ) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectIngredientsPage(
          repo: repo,
          preselectedExpiring: expiringItems,
        ),
      ),
    );

    // 如果在 Select/Recipe 那边有动库存，这里刷新一下
    if (changed == true) {
      onRefresh();
    }
  }

  Widget _buildAiButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF003B66),
              Color(0xFF0A6BA8),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "AI Recipe Suggestions",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== 顶部 Impact 卡片 ==================

  Widget _buildImpactSummary(BuildContext context) {
    final saved = repo.getSavedCount();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF005F87), Color(0xFF0082B0)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sustainability Goal',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '$saved items are saved this week!',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Fridge is fresh!',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _undoLabelForAction(String action, String name) {
    switch (action) {
      case 'eat':
        return 'Marked "$name" as cooked. Tap UNDO to revert.';
      case 'pet':
        return 'Fed "$name" to pet. Tap UNDO to revert.';
      case 'trash':
        return 'Discarded "$name". Tap UNDO to revert.';
      default:
        return 'Updated "$name". Tap UNDO to revert.';
    }
  }
}
