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
      appBar: AppBar(
        title: const Text('Smart Food Home'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildImpactSummary(context),
          const SizedBox(height: 14),

          _buildAiButton(
            context,
            onTap: () => _showAiRecipeFlow(context, expiring),
          ),

          const SizedBox(height: 18),

          _buildSectionHeader(context, expiring.length),

          const SizedBox(height: 10),

          if (expiring.isEmpty)
            _buildEmptyState(context)
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
                        content: Text('Please ensure the food is safe for your pet!'),
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
                          content: Text(_undoLabelForAction(action, item.name)),
                          action: SnackBarAction(
                            label: 'UNDO',
                            onPressed: () async {
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

    if (changed == true) onRefresh();
  }

  // ================== 顶部 Impact 卡片（更“高级感”） ==================

  Widget _buildImpactSummary(BuildContext context) {
    final saved = repo.getSavedCount();

    return Container(
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0A5678),
            Color(0xFF0E7AA8),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 背景装饰：两团柔和光斑（不影响内容）
          Positioned(
            right: -40,
            top: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.eco, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This week',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.80),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$saved',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              saved == 1 ? 'item saved' : 'items saved',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Keep it up — fewer items wasted.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
    );
  }

  // ================== AI 按钮（更现代、更统一） ==================

  Widget _buildAiButton(BuildContext context, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF0A3F6B),
                Color(0xFF176FA6),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, 10),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'AI Recipe Suggestions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================== Section Header（更干净） ==================

  Widget _buildSectionHeader(BuildContext context, int count) {
    return Row(
      children: [
        Text(
          'Expiring Soon',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0A6BA8).withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF0A6BA8).withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF0A6BA8),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const Spacer(),
        Text(
          '$count items',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  // ================== Empty State（更像“卡片”） ==================

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 14,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0A6BA8).withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF0A6BA8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All good!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fridge is fresh. No items expiring in the next 3 days.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
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
