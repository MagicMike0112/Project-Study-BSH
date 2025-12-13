// lib/screens/select_ingredients_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../utils/auth_guard.dart'; // 👈 登录检查

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
  State<SelectIngredientsPage> createState() => _SelectIngredientsPageState();
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
    // ✅ AI 菜谱前先要求登录
    final ok = await requireLogin(context);
    if (!ok) return;

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
            _hasChanged = true;
            setState(() {
              _activeItems = widget.repo.getActiveItems();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF6F8FA);
    final selectedCount = _selectedIds.length;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text('Choose ingredients'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
            children: [
              _HeroCard(
                selectedCount: selectedCount,
                preselectedCount: widget.preselectedExpiring.length,
              ),
              const SizedBox(height: 12),

              // ===== From inventory =====
              _SectionCard(
                title: 'From your inventory',
                subtitle: _activeItems.isEmpty
                    ? 'No items in your inventory yet.'
                    : 'Tap an item to include it in today\'s AI recipes.',
                child: _activeItems.isEmpty
                    ? _EmptyHint(
                        icon: Icons.inventory_2_outlined,
                        title: 'No inventory items',
                        subtitle:
                            'Add items first, then generate recipes here.',
                      )
                    : Column(
                        children: _activeItems.map((item) {
                          final selected = _selectedIds.contains(item.id);
                          final days = item.daysToExpiry;
                          final leftText =
                              days >= 999 ? 'no expiry set' : '$days days left';

                          final urgency = days >= 999
                              ? _Urgency.neutral
                              : days <= 1
                                  ? _Urgency.high
                                  : days <= 3
                                      ? _Urgency.medium
                                      : _Urgency.low;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InventoryPickTile(
                              name: item.name,
                              qtyText: '${item.quantity} ${item.unit}',
                              expiryText: leftText,
                              urgency: urgency,
                              selected: selected,
                              onTap: () => _toggleSelected(item),
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
                    'Not in inventory but you plan to use today (e.g. rice, noodles, sauces).',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InputRow(
                      controller: _extraController,
                      hintText: 'Type an ingredient',
                      onSubmit: _addExtraIngredient,
                      onAdd: _addExtraIngredient,
                    ),
                    const SizedBox(height: 10),
                    if (_extraIngredients.isEmpty)
                      _EmptyHint(
                        icon: Icons.add_circle_outline,
                        title: 'No extra ingredients',
                        subtitle:
                            'Optional — add staples to help AI complete dishes.',
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _extraIngredients
                            .map(
                              (e) => Chip(
                                label: Text(e),
                                onDeleted: () => _removeExtraIngredient(e),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 12),
                    _ToggleRow(
                      value: _addExtrasToInventory,
                      title: 'Also add new ingredients to inventory',
                      subtitle:
                          'Use this only for fresh ingredients you want to track (not condiments).',
                      onChanged: (v) =>
                          setState(() => _addExtrasToInventory = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ===== Special request =====
              _SectionCard(
                title: 'Special request',
                subtitle:
                    'Diet preferences or style, e.g. “vegan”, “no peanuts”, “Chinese style”, “high protein”…',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _specialRequestController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Optional…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
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
            ],
          ),
        ),

        // 底部主按钮（渐变 + 更有质感）
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: _GradientPrimaryButton(
              onTap: _confirm,
              icon: Icons.auto_awesome,
              title: 'Use these ingredients',
              subtitle: selectedCount == 0
                  ? 'Select at least 1 item to get recipes'
                  : '$selectedCount selected • generate recipes',
              enabled: selectedCount > 0 || _extraIngredients.isNotEmpty,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ================== 顶部 Hero 卡 ==================

class _HeroCard extends StatelessWidget {
  final int selectedCount;
  final int preselectedCount;

  const _HeroCard({
    required this.selectedCount,
    required this.preselectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF003B66), Color(0xFF0A6BA8)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -30,
              child: _GlassCircle(size: 150),
            ),
            Positioned(
              left: 120,
              bottom: -60,
              child: _GlassCircle(size: 180),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI will prioritize expiring items',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$selectedCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                height: 1.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                'selected',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preselectedCount == 0
                              ? 'Select items to generate recipes.'
                              : '$preselectedCount items were pre-selected.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
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
      ),
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
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
    );
  }
}

// ================== Inventory pick tile（更清晰） ==================

enum _Urgency { high, medium, low, neutral }

class _InventoryPickTile extends StatelessWidget {
  final String name;
  final String qtyText;
  final String expiryText;
  final _Urgency urgency;
  final bool selected;
  final VoidCallback onTap;

  const _InventoryPickTile({
    required this.name,
    required this.qtyText,
    required this.expiryText,
    required this.urgency,
    required this.selected,
    required this.onTap,
  });

  Color _badgeBg() {
    switch (urgency) {
      case _Urgency.high:
        return Colors.red.withOpacity(0.10);
      case _Urgency.medium:
        return Colors.orange.withOpacity(0.12);
      case _Urgency.low:
        return Colors.green.withOpacity(0.12);
      case _Urgency.neutral:
        return Colors.black.withOpacity(0.06);
    }
  }

  Color _badgeFg() {
    switch (urgency) {
      case _Urgency.high:
        return Colors.redAccent;
      case _Urgency.medium:
        return Colors.deepOrange;
      case _Urgency.low:
        return Colors.green.shade700;
      case _Urgency.neutral:
        return Colors.grey.shade700;
    }
  }

  IconData _leadIcon() {
    switch (urgency) {
      case _Urgency.high:
        return Icons.warning_amber_rounded;
      case _Urgency.medium:
        return Icons.schedule;
      case _Urgency.low:
        return Icons.eco;
      case _Urgency.neutral:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
            width: 1.2,
          )
        : Border.all(color: Colors.black.withOpacity(0.06));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: border,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _badgeBg(),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _leadIcon(),
                  color: _badgeFg(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$qtyText • $expiryText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  selected ? Icons.check : Icons.add,
                  size: 18,
                  color: selected ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== Extra input row ==================

class _InputRow extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onAdd;
  final VoidCallback onSubmit;

  const _InputRow({
    required this.controller,
    required this.hintText,
    required this.onAdd,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 48,
          width: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onAdd,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// ================== Toggle row ==================

class _ToggleRow extends StatelessWidget {
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================== Empty hint ==================

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================== Gradient primary button ==================

class _GradientPrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;

  const _GradientPrimaryButton({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [Color(0xFF003B66), Color(0xFF0A6BA8)],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            height: 58,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Icon(icon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

      final uri = Uri.parse('https://project-study-bsh.vercel.app/api/recipe');

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
          throw Exception('Unexpected "recipes" type: ${inner.runtimeType}');
        }
      } else if (root is List) {
        rawList = root;
      } else {
        throw Exception('Unexpected JSON root type: ${root.runtimeType}');
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
    final bg = const Color(0xFFF6F8FA);

    return Scaffold(
      backgroundColor: bg,
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
              'We prioritize expiring items first, and use extra ingredients to complete dishes.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected items',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (widget.items.isEmpty)
                _EmptyHint(
                  icon: Icons.info_outline,
                  title: 'Nothing selected',
                  subtitle: 'Go back and select at least one item.',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children:
                      widget.items.map((i) => Chip(label: Text(i.name))).toList(),
                ),
              const SizedBox(height: 14),
              if (widget.extraIngredients.isNotEmpty) ...[
                const Text(
                  'Extra ingredients',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: widget.extraIngredients
                      .map((e) => Chip(label: Text(e)))
                      .toList(),
                ),
                const SizedBox(height: 14),
              ],
              if (widget.specialRequest != null &&
                  widget.specialRequest!.trim().isNotEmpty) ...[
                const Text(
                  'Special request',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    widget.specialRequest!,
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        _GradientPrimaryButton(
          onTap: _generate,
          icon: Icons.auto_awesome,
          title: 'Generate recipes',
          subtitle: 'AI will use your selection',
          enabled: true,
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            )
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 12),
            Text(
              'Generating recipes…',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Optimizing for expiring items',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_recipes.isEmpty) {
      return const Center(child: Text('No recipes generated.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI recipes for your fridge',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 6),
        Text(
          'We created several ideas using expiring items first.',
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            itemCount: _recipes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62, // ✅ 更高更稳：彻底避免 bottom overflow
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

// ================== 网格里的单个菜谱卡片（只展示关键数据，不溢出） ==================

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
      borderRadius: BorderRadius.circular(18),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部图片区：Stack 叠加 expiring 角标（不占内容区高度）
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  Container(
                    height: 92,
                    width: double.infinity,
                    color: scheme.primaryContainer.withOpacity(0.35),
                    alignment: Alignment.center,
                    child: const Icon(Icons.fastfood, size: 42),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _BadgePill(
                      icon: Icons.recycling,
                      text: '${recipe.expiringCount}',
                      bg: scheme.primary.withOpacity(0.12),
                      fg: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // 内容区：标题(2行) + 时间(1个pill)，其余不显示（避免溢出）
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoPill(
                    icon: Icons.schedule,
                    text: recipe.timeLabel,
                    bg: Colors.black.withOpacity(0.06),
                    fg: Colors.grey.shade800,
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  const _BadgePill({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ================== 详情页（更清晰、更可读） ==================

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
    final bg = const Color(0xFFF6F8FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: Text(recipe.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primaryContainer.withOpacity(0.55),
                    scheme.secondaryContainer.withOpacity(0.35),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.fastfood, size: 72),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            recipe.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          // ✅ 详情页可显示全信息（这里不会溢出）
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: Icons.schedule,
                text: recipe.timeLabel,
                color: Colors.black.withOpacity(0.06),
                textColor: Colors.grey[800]!,
                iconColor: Colors.grey[700]!,
              ),
              _Pill(
                icon: Icons.recycling,
                text: '${recipe.expiringCount} expiring items',
                color: scheme.primary.withOpacity(0.12),
                textColor: scheme.primary,
                iconColor: scheme.primary,
              ),
              _Pill(
                icon: Icons.list_alt,
                text: '${recipe.ingredients.length} ingredients',
                color: Colors.black.withOpacity(0.06),
                textColor: Colors.grey[800]!,
                iconColor: Colors.grey[700]!,
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (recipe.description != null) ...[
            _InfoCard(
              title: 'Overview',
              icon: Icons.info_outline,
              child: Text(
                recipe.description!,
                style: TextStyle(color: Colors.grey[800], height: 1.25),
              ),
            ),
            const SizedBox(height: 12),
          ],

          _InfoCard(
            title: 'Ingredients',
            icon: Icons.shopping_basket_outlined,
            child: Column(
              children: recipe.ingredients
                  .map(
                    (ing) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 7),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(ing)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 12),

          _InfoCard(
            title: 'Steps',
            icon: Icons.format_list_numbered,
            child: Column(
              children: recipe.steps.asMap().entries.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${e.key + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(height: 1.25),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 18),

          _GradientPrimaryButton(
            onTap: () async {
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
                    const SnackBar(content: Text('Inventory updated ✅')),
                  );
                }
              }

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: Icons.check,
            title: 'I cooked this',
            subtitle: 'Mark selected items as used',
            enabled: true,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;
  final Color iconColor;

  const _Pill({
    required this.icon,
    required this.text,
    required this.color,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[800]),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
