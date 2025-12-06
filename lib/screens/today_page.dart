// lib/screens/today_page.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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

          if (expiring.isNotEmpty)
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
                  switch (action) {
                    case 'eat':
                      repo.logCooked(item);
                      await repo.updateStatus(
                        item.id,
                        FoodStatus.consumed,
                      );
                      break;
                    case 'pet':
                      // 第一次喂宠物弹安全提示
                      if (!repo.hasShownPetWarning) {
                        repo.hasShownPetWarning = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '请只喂适合宠物食用的食材，若不确定请先咨询兽医🐹',
                            ),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                      repo.logFedToPet(item);
                      await repo.updateStatus(
                        item.id,
                        FoodStatus.consumed,
                      );
                      break;
                    case 'trash':
                      await repo.updateStatus(
                        item.id,
                        FoodStatus.discarded,
                      );
                      break;
                  }
                  onRefresh();
                },
              ),
            ),
        ],
      ),
    );
  }

  // ================== AI Flow ==================

  Future<void> _showAiRecipeFlow(
    BuildContext context,
    List<FoodItem> expiringItems,
  ) async {
    // 1. 先让用户在所有库存 + 额外输入里选择食材
    final result = await Navigator.push<AiCookingSelectionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectIngredientsPage(
          repo: repo,
          preselectedExpiring: expiringItems,
        ),
      ),
    );

    if (result == null) return; // 用户取消

    // 2. 如果用户勾选“将额外食材加入库存”，这里补充入库
    if (result.addExtrasToInventory) {
      for (final extra in result.extraIngredients) {
        await repo.addItem(
          FoodItem(
            id: const Uuid().v4(),
            name: extra,
            location: StorageLocation.fridge,
            quantity: 1,
            unit: 'pcs',
            purchasedDate: DateTime.now(),
            predictedExpiry: null,
            status: FoodStatus.good,
          ),
        );
      }
      onRefresh();
    }

    // 3. 打开 AI 菜谱生成的 BottomSheet，
    //   把选中食材 + 额外食材一起传进去
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecipeGeneratorSheet(
        items: result.selectedInventoryItems,
        extraIngredients: result.extraIngredients,
      ),
    );
  }

  // ✨ AI 按钮
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

  // ================== 其余 UI 保持原逻辑 ==================

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
                  'You saved $saved items this week!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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
}

// ================== 智能菜谱模型 ==================

class RecipeSuggestion {
  final String id;
  final String title;
  final String timeLabel; // e.g. "15 min · 1 pan"
  final int expiringCount; // 使用了多少个 expiring items
  final List<String> ingredients; // 展示用
  final List<String> steps; // 详细步骤
  final String? description;
  final String? imageUrl; // 未来接真实图片，这里先占位

  RecipeSuggestion({
    required this.id,
    required this.title,
    required this.timeLabel,
    required this.expiringCount,
    required this.ingredients,
    required this.steps,
    this.description,
    this.imageUrl,
  });
}

// ================== Recipe Generator BottomSheet ==================

class RecipeGeneratorSheet extends StatefulWidget {
  final List<FoodItem> items;
  final List<String> extraIngredients;

  const RecipeGeneratorSheet({
    super.key,
    required this.items,
    required this.extraIngredients,
  });

  @override
  State<RecipeGeneratorSheet> createState() => _RecipeGeneratorSheetState();
}

class _RecipeGeneratorSheetState extends State<RecipeGeneratorSheet> {
  int _state = 0; // 0 配置, 1 loading, 2 结果
  List<RecipeSuggestion> _recipes = [];

  void _generate() async {
    setState(() => _state = 1);

    // 这里未来换成真正调用 LLM API 的逻辑
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // ======= DEMO 数据：用选中食材 + 额外输入生成几道假菜 =======
    final baseNames =
        widget.items.map((e) => e.name).toList() + widget.extraIngredients;

    final expiringCount = widget.items.length;
    final List<RecipeSuggestion> demo = [
      RecipeSuggestion(
        id: 'r1',
        title: 'Quick ${baseNames.isNotEmpty ? baseNames.first : 'Smart'} Stir-fry',
        timeLabel: '15 min · 1 pan',
        expiringCount: expiringCount,
        ingredients: [
          ...widget.items.map((e) => '${e.name} (${e.quantity} ${e.unit})'),
          ...widget.extraIngredients,
        ],
        steps: const [
          'Prepare and chop all ingredients.',
          'Heat a pan with some oil.',
          'Stir-fry expiring items first until slightly soft.',
          'Add remaining ingredients, season to taste.',
          'Serve immediately.'
        ],
        description: 'Uses all your expiring items in a simple one-pan meal.',
      ),
      RecipeSuggestion(
        id: 'r2',
        title: '${baseNames.isNotEmpty ? baseNames.first : 'Fridge'} Frittata',
        timeLabel: '20 min · oven',
        expiringCount: expiringCount,
        ingredients: [
          ...widget.items.map((e) => e.name),
          'Eggs',
          'Cheese (optional)',
        ],
        steps: const [
          'Preheat oven and lightly grease a baking dish.',
          'Whisk eggs with salt & pepper.',
          'Add chopped expiring ingredients into the dish.',
          'Pour egg mixture on top and bake until set.',
          'Serve warm.'
        ],
        description: 'Turn your almost-expiring veggies into a baked frittata.',
      ),
      RecipeSuggestion(
        id: 'r3',
        title: 'Zero-waste ${baseNames.isNotEmpty ? baseNames.first : 'Veggie'} Soup',
        timeLabel: '25 min · pot',
        expiringCount: expiringCount,
        ingredients: [
          ...widget.items.map((e) => e.name),
          'Stock or water',
          'Salt, pepper, herbs',
        ],
        steps: const [
          'Chop all expiring vegetables into small pieces.',
          'Sauté them briefly with oil.',
          'Add stock or water and bring to a boil.',
          'Simmer until everything is soft, season to taste.',
          'Optionally blend for a creamy soup.'
        ],
        description:
            'A warm soup that uses leftover veggies and is easy to freeze.',
      ),
    ];

    setState(() {
      _recipes = demo;
      _state = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: _state == 0
          ? _buildConfig()
          : _state == 1
              ? _buildLoading()
              : _buildResult(),
    );
  }

  // Step 0: 配置页（展示选中食材 + 额外输入）
  Widget _buildConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "AI recipe generator",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "We will prioritize expiring items and use extra ingredients to complete the dish.",
        ),
        const SizedBox(height: 16),
        const Text(
          'Selected inventory items',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: widget.items
              .map(
                (i) => Chip(label: Text(i.name)),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        if (widget.extraIngredients.isNotEmpty) ...[
          const Text(
            'Extra ingredients',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.extraIngredients
                .map((e) => Chip(label: Text(e)))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _generate,
            child: const Text("Generate recipes"),
          ),
        ),
      ],
    );
  }

  // Step 1: loading
  Widget _buildLoading() =>
      const Center(child: CircularProgressIndicator());

  // Step 2: 结果页——两列网格 + 点击进入详情
  Widget _buildResult() {
    if (_recipes.isEmpty) {
      return const Center(
        child: Text("No recipes generated."),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "AI recipes for your fridge",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "We created ${_recipes.length} ideas using your expiring items first.",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            itemCount: _recipes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, index) {
              final recipe = _recipes[index];
              return _RecipeCard(
                recipe: recipe,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailPage(recipe: recipe),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// 网格中的菜谱卡片
class _RecipeCard extends StatelessWidget {
  final RecipeSuggestion recipe;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片占位（未来可以换成真实图片）
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                height: 90,
                width: double.infinity,
                color: scheme.primaryContainer.withOpacity(0.4),
                child: const Icon(
                  Icons.fastfood,
                  size: 40,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                recipe.timeLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.recycling,
                    size: 14,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${recipe.expiringCount} expiring',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.primary,
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

// ================== 菜谱详情页 ==================

class RecipeDetailPage extends StatelessWidget {
  final RecipeSuggestion recipe;

  const RecipeDetailPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 180,
              width: double.infinity,
              color: scheme.primaryContainer.withOpacity(0.5),
              child: const Icon(
                Icons.fastfood,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            recipe.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text(recipe.timeLabel),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: const Icon(Icons.recycling, size: 16),
                label: Text('${recipe.expiringCount} expiring items'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recipe.description != null) ...[
            Text(
              recipe.description!,
              style: TextStyle(color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Ingredients',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...recipe.ingredients.map(
            (ing) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(ing)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Steps',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...recipe.steps.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.key + 1}. '),
                      Expanded(child: Text(e.value)),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                // 这里未来可以触发：logCooked + 关闭页面
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check),
              label: const Text('I cooked this'),
            ),
          ),
        ],
      ),
    );
  }
}
