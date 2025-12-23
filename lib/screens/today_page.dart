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

  // 定义页面级的主题颜色，保持一致性
  static const Color _primaryBlue = Color(0xFF0E7AA8);
  static const Color _surfaceColor = Color(0xFFF8F9FC);

  @override
  Widget build(BuildContext context) {
    final expiring = repo.getExpiringItems(3);

    return Scaffold(
      backgroundColor: _surfaceColor, // 更柔和的背景色
      appBar: AppBar(
        title: const Text(
          'Smart Food Home',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false, // 现代设计通常靠左，更符合阅读习惯
        backgroundColor: _surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 1. 情感化激励 (Impact Summary) - 视觉降噪，作为 Header 存在
          _buildImpactSummary(context),
          
          const SizedBox(height: 24),

          // 2. 核心行动入口 (AI Button) - 视觉增强，鼓励点击
          _buildAiButton(
            context,
            onTap: () => _showAiRecipeFlow(context, expiring),
          ),

          const SizedBox(height: 32),

          // 3. 紧急事项标题
          _buildSectionHeader(context, expiring.length),

          const SizedBox(height: 16),

          // 4. 列表内容
          if (expiring.isEmpty)
            _buildEmptyState(context)
          else
            ...expiring.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12), // 卡片间距增加
                child: FoodCard(
                  item: item,
                  // 优化后的 Leading 图标，减少视觉干扰
                  leading: _buildInventoryStyleLeading(item),
                  onAction: (action) async {
                    // --- 保持原有业务逻辑不变 ---
                    final oldStatus = item.status;
                    await repo.recordImpactForAction(item, action);

                    FoodStatus? newStatus;
                    if (action == 'eat' || action == 'pet') {
                      newStatus = FoodStatus.consumed;
                    } else if (action == 'trash') {
                      newStatus = FoodStatus.discarded;
                    }

                    if (newStatus != null) {
                      await repo.updateStatus(item.id, newStatus);
                    }

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

                    if (newStatus != null) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            // 🔴 修改点：改为 fixed，去掉 margin，让它紧贴底部 Tab
                            behavior: SnackBarBehavior.fixed,
                            backgroundColor: const Color(0xFF323232), // 深灰色背景
                            duration: const Duration(seconds: 3),
                            content: Text(
                              _undoLabelForAction(action, item.name),
                              style: const TextStyle(color: Colors.white),
                            ),
                            action: SnackBarAction(
                              label: 'UNDO',
                              textColor: const Color(0xFF81D4FA), // 浅蓝色按钮，对比度高
                              onPressed: () async {
                                await repo.updateStatus(item.id, oldStatus);
                                onRefresh();
                              },
                            ),
                          ),
                        );
                    }
                    onRefresh();
                    // --- 业务逻辑结束 ---
                  },
                ),
              ),
            ),
          
          // 底部留白，防止内容贴底
          const SizedBox(height: 40),
        ],
      ),
    );
  }

// ================== AI Flow 跳转逻辑 ==================

  Future<void> _showAiRecipeFlow(
    BuildContext context,
    List<FoodItem> expiringItems,
  ) async {
    // 确保你的文件头部引用了 select_ingredients_page.dart
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectIngredientsPage(
          repo: repo,
          preselectedExpiring: expiringItems,
        ),
      ),
    );

    // 如果在下一个页面做了修改（比如消耗了食材），返回后刷新页面
    if (changed == true) onRefresh();
  }

  // ================== ✅ 优化后的 Inventory Style Leading ==================
  // 去掉了边框，改用更轻盈的底色，减少列表的“格子感”
  Widget _buildInventoryStyleLeading(FoodItem item) {
    final leading = _leadingIcon(item);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: leading.color.withOpacity(0.08), // 更淡的背景
        borderRadius: BorderRadius.circular(14), // 更圆润
      ),
      child: Icon(leading.icon, color: leading.color, size: 22),
    );
  }

  _Leading _leadingIcon(FoodItem item) {
    switch (item.location) {
      case StorageLocation.fridge:
        return const _Leading(Icons.kitchen_rounded, Color(0xFF005F87));
      case StorageLocation.freezer:
        return const _Leading(Icons.ac_unit_rounded, Color(0xFF3F51B5));
      case StorageLocation.pantry:
        return const _Leading(Icons.shelves, Color(0xFF795548));
    }
  }

  // ================== ✅ 优化后的 Impact Summary ==================
  // 此时它不再是一个巨大的色块，而是一个清爽的数据展示区
  Widget _buildImpactSummary(BuildContext context) {
    final saved = repo.getSavedCount();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)), // 极淡的边框
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左侧：Icon 和 激励语
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD), // 浅蓝色背景
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.eco_rounded, color: _primaryBlue, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact this week',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    textBaseline: TextBaseline.alphabetic,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep it up!',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // 右侧：巨大的数字，强调成就感
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$saved',
                style: const TextStyle(
                  color: _primaryBlue,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              Text(
                saved == 1 ? 'item saved' : 'items saved',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================== ✅ 优化后的 AI Button ==================
  // 更加突出，使用深色背景吸引点击，暗示这是解决问题的“魔法”
  Widget _buildAiButton(BuildContext context, {required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A3F6B).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            height: 72, //稍微加高一点，增加点击区域
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E293B), // 深岩石蓝
                  Color(0xFF0F172A), // 近乎黑的蓝
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF60A5FA), size: 24), // 亮蓝色图标
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Chef',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Cook with expiring items',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================== ✅ 优化后的 Section Header ==================
  // 极简主义，去掉了多余的边框和文字
  Widget _buildSectionHeader(BuildContext context, int count) {
    return Row(
      children: [
        Text(
          'Expiring Soon',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: -0.5,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEAEA), // 非常浅的红色背景，示警但不刺眼
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  // ================== ✅ 优化后的 Empty State ==================
  // 更加平面化，融入背景
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center, 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.green,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your fridge is fresh and organized.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _undoLabelForAction(String action, String name) {
    switch (action) {
      case 'eat':
        return 'Cooked "$name"';
      case 'pet':
        return 'Fed "$name" to pet';
      case 'trash':
        return 'Discarded "$name"';
      default:
        return 'Updated "$name"';
    }
  }
}

class _Leading {
  final IconData icon;
  final Color color;
  const _Leading(this.icon, this.color);
}