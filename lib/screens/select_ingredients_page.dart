// lib/screens/select_ingredients_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';

// ================== 选食材页面 ==================

class SelectIngredientsPage extends StatefulWidget {
  final InventoryRepository repo;

  /// 预选中的“快过期”食材
  final List<FoodItem> preselectedExpiring;

  const SelectIngredientsPage({
    super.key,
    required this.repo,
    required this.preselectedExpiring,
  });

  @override
  State<SelectIngredientsPage> createState() =>
      _SelectIngredientsPageState();
}

class _SelectIngredientsPageState extends State<SelectIngredientsPage> {
  late List<FoodItem> _activeItems;
  final Set<String> _selectedIds = {};
  final List<String> _extraIngredients = [];
  bool _addExtrasToInventory = false;

  final TextEditingController _extraController = TextEditingController();

  /// 特殊要求（菜系 / 饮食偏好）
  final TextEditingController _specialRequestController =
      TextEditingController();

  /// 记录在本页面 / AI 菜谱里有没有对库存产生影响
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _activeItems = widget.repo.getActiveItems();

    // 预选中快要过期的
    for (final item in widget.preselectedExpiring) {
      _selectedIds.add(item.id);
    }
  }

  @override
  void dispose() {
    _extraController.dispose();
    _specialRequestController.dispose();
    super.dispose();
  }

  void _toggleSelected(FoodItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _addExtraIngredient() {
    final text = _extraController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _extraIngredients.add(text);
      _extraController.clear();
    });
  }

  void _removeExtraIngredient(String ing) {
    setState(() {
      _extraIngredients.remove(ing);
    });
  }

  Future<void> _confirm() async {
    final selected = _activeItems
        .where((item) => _selectedIds.contains(item.id))
        .toList();

    final requestText = _specialRequestController.text.trim();
    final special = requestText.isEmpty ? null : requestText;

    // 可选：把 extra 食材加进 inventory
    if (_addExtrasToInventory) {
      for (final extra in _extraIngredients) {
        await widget.repo.addItem(
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
      _hasChanged = true;
      setState(() {
        _activeItems = widget.repo.getActiveItems();
      });
    }

    // 进入 AI 菜谱页面
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeGeneratorSheet(
          repo: widget.repo,
          items: selected,
          extraIngredients: List.unmodifiable(_extraIngredients),
          specialRequest: special,
          onInventoryUpdated: () {
            // 在菜谱详情里点击 “I cooked this” 后会调用
            _hasChanged = true;
            setState(() {
              _activeItems = widget.repo.getActiveItems();
            });
          },
        ),
      ),
    );

    // 不在这里 pop；让用户回到本页再决定是否回 Today
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 返回 Today 时，把是否有变动传回去（bool）
        Navigator.pop(context, _hasChanged);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose ingredients'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'How it works',
                subtitle:
                    'We pre-selected items that are expiring soon. You can adjust the selection and add more ingredients.',
                child: const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // ===== From inventory =====
              _SectionCard(
                title: 'From your inventory',
                subtitle: _activeItems.isEmpty
                    ? 'No items in your inventory yet.'
                    : 'Tap to include items in today\'s AI recipes.',
                child: _activeItems.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        children: _activeItems.map((item) {
                          final selected = _selectedIds.contains(item.id);
                          final days = item.daysToExpiry;
                          final leftText = days >= 999
                              ? 'no expiry set'
                              : '$days days left';

                          return CheckboxListTile(
                            value: selected,
                            onChanged: (_) => _toggleSelected(item),
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.quantity} ${item.unit} • $leftText',
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 12),

              // ===== Extra ingredients =====
              _SectionCard(
                title: 'Extra ingredients',
                subtitle:
                    'Things that are not in your inventory but you plan to use today (e.g. rice, noodles, sauces).',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _extraController,
                            decoration: const InputDecoration(
                              hintText: 'Add extra ingredient',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addExtraIngredient(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addExtraIngredient,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _extraIngredients
                          .map(
                            (e) => Chip(
                              label: Text(e),
                              onDeleted: () => _removeExtraIngredient(e),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _addExtrasToInventory,
                          onChanged: (v) => setState(
                            () => _addExtrasToInventory = v ?? false,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Also add new ingredients to inventory',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Use this only for fresh ingredients you want to track, not condiments.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ===== Special request =====
              _SectionCard(
                title: 'Special request (optional)',
                subtitle:
                    'Dietary preferences or style, e.g. “vegan”, “no peanuts”, “Chinese style”, “high protein”…',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _specialRequestController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We will send this to AI together with your ingredients.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80), // 给底部按钮留一点滚动空间
            ],
          ),
        ),

        // 底部主按钮，和其他页面统一
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Use these ingredients'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================== 通用 Section 卡片 ==================

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (child is! SizedBox) ...[
              const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

// ================== Recipe 数据模型 ==================

class RecipeSuggestion {
  final String id;
  final String title;
  final String timeLabel;
  final int expiringCount;
  final List<String> ingredients;
  final List<String> steps;
  final String? description;
  final String? imageUrl;

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

// ================== Recipe Generator 页面 ==================

class RecipeGeneratorSheet extends StatefulWidget {
  final InventoryRepository repo;
  final List<FoodItem> items;
  final List<String> extraIngredients;
  final String? specialRequest;
  final VoidCallback? onInventoryUpdated;

  const RecipeGeneratorSheet({
    super.key,
    required this.repo,
    required this.items,
    required this.extraIngredients,
    this.specialRequest,
    this.onInventoryUpdated,
  });

  @override
  State<RecipeGeneratorSheet> createState() => _RecipeGeneratorSheetState();
}

class _RecipeGeneratorSheetState extends State<RecipeGeneratorSheet> {
  int _state = 0; // 0 配置, 1 loading, 2 结果
  List<RecipeSuggestion> _recipes = [];

  Future<void> _generate() async {
    setState(() => _state = 1);

    try {
      final ingredients = widget.items
          .map((i) => '${i.name} (${i.quantity} ${i.unit})')
          .toList();

      final uri =
          Uri.parse('https://project-study-bsh.vercel.app/api/recipe');

      final body = <String, dynamic>{
        'ingredients': ingredients,
        'extraIngredients': widget.extraIngredients,
      };

      if (widget.specialRequest != null &&
          widget.specialRequest!.trim().isNotEmpty) {
        body['specialRequest'] = widget.specialRequest!.trim();
      }

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Server error: ${resp.statusCode} - ${resp.body}');
      }

      final root = jsonDecode(resp.body);

      List<dynamic> rawList;

      if (root is Map<String, dynamic>) {
        final inner = root['recipes'];
        if (inner is List) {
          rawList = inner;
        } else if (inner is Map) {
          rawList = [inner];
        } else if (inner == null) {
          rawList = const [];
        } else {
          throw Exception(
              'Unexpected "recipes" type: ${inner.runtimeType}');
        }
      } else if (root is List) {
        rawList = root;
      } else {
        throw Exception(
            'Unexpected JSON root type: ${root.runtimeType}');
      }

      _recipes = rawList.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return RecipeSuggestion(
          id: m['id']?.toString() ?? const Uuid().v4(),
          title: m['title'] ?? 'Untitled',
          timeLabel: m['timeLabel'] ?? '20 min',
          expiringCount: (m['expiringCount'] ?? 0) as int,
          ingredients: (m['ingredients'] as List<dynamic>? ?? const [])
              .map((x) => x.toString())
              .toList(),
          steps: (m['steps'] as List<dynamic>? ?? const [])
              .map((x) => x.toString())
              .toList(),
          description: m['description']?.toString(),
        );
      }).toList();

      if (!mounted) return;
      setState(() => _state = 2);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI recipe failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI recipes'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _state == 0
              ? _buildConfig()
              : _state == 1
                  ? _buildLoading()
                  : _buildResult(),
        ),
      ),
    );
  }

  Widget _buildConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'AI recipe generator',
          subtitle:
              'We will prioritize expiring items and use extra ingredients to complete the dish.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected inventory items',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.items
                    .map((i) => Chip(label: Text(i.name)))
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
              if (widget.specialRequest != null &&
                  widget.specialRequest!.trim().isNotEmpty) ...[
                const Text(
                  'Special request',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.specialRequest!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _generate,
            child: const Text('Generate recipes'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() =>
      const Center(child: CircularProgressIndicator());

  Widget _buildResult() {
    if (_recipes.isEmpty) {
      return const Center(
        child: Text('No recipes generated.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI recipes for your fridge',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'We created several ideas using your expiring items first.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            itemCount: _recipes.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
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
                      builder: (_) => RecipeDetailPage(
                        recipe: recipe,
                        repo: widget.repo,
                        usedItems: widget.items,
                        onInventoryUpdated: widget.onInventoryUpdated,
                      ),
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

// 网格里的单个菜谱卡片
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

// 详情页
class RecipeDetailPage extends StatelessWidget {
  final RecipeSuggestion recipe;
  final InventoryRepository repo;
  final List<FoodItem> usedItems;
  final VoidCallback? onInventoryUpdated;

  const RecipeDetailPage({
    super.key,
    required this.recipe,
    required this.repo,
    required this.usedItems,
    this.onInventoryUpdated,
  });

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
              onPressed: () async {
                final shouldUpdate = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('Update inventory?'),
                      content: const Text(
                        'Did you use up the selected ingredients from your fridge for this recipe?\n'
                        'If yes, we will mark them as cooked and remove them from your inventory.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Skip'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Update'),
                        ),
                      ],
                    );
                  },
                );

                if (shouldUpdate == true) {
                  for (final item in usedItems) {
                    await repo.recordImpactForAction(item, 'eat');
                    await repo.updateStatus(item.id, FoodStatus.consumed);
                  }
                  onInventoryUpdated?.call();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Inventory updated ✅'),
                      ),
                    );
                  }
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
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
