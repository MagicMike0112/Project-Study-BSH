// lib/screens/select_ingredients_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../utils/auth_guard.dart'; // 👈 登录检查

// ================== Recipe archive (local) ==================

const String _kRecipeArchiveKey = 'recipe_archive_v1';

class RecipeArchiveEntry {
  final RecipeSuggestion recipe;
  final DateTime addedAt;

  RecipeArchiveEntry({
    required this.recipe,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'recipe': recipe.toJson(),
        'addedAt': addedAt.toIso8601String(),
      };

  static RecipeArchiveEntry fromJson(Map<String, dynamic> json) {
    final r = (json['recipe'] as Map).cast<String, dynamic>();
    return RecipeArchiveEntry(
      recipe: RecipeSuggestion.fromJson(r),
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class RecipeArchiveStore {
  static Future<List<RecipeArchiveEntry>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kRecipeArchiveKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => (e as Map).cast<String, dynamic>())
          .map(RecipeArchiveEntry.fromJson)
          .toList();

      // newest first
      list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(RecipeSuggestion recipe) async {
    final sp = await SharedPreferences.getInstance();
    final list = await load();

    // de-dup by id: keep newest
    final filtered = list.where((e) => e.recipe.id != recipe.id).toList();
    filtered.insert(
      0,
      RecipeArchiveEntry(recipe: recipe, addedAt: DateTime.now()),
    );

    final encoded = jsonEncode(filtered.map((e) => e.toJson()).toList());
    await sp.setString(_kRecipeArchiveKey, encoded);
  }

  static Future<void> remove(String recipeId) async {
    final sp = await SharedPreferences.getInstance();
    final list = await load();
    final filtered = list.where((e) => e.recipe.id != recipeId).toList();
    final encoded = jsonEncode(filtered.map((e) => e.toJson()).toList());
    await sp.setString(_kRecipeArchiveKey, encoded);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kRecipeArchiveKey);
  }
}

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
  final TextEditingController _specialRequestController = TextEditingController();

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

  Future<void> _openArchive() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeArchivePage(repo: widget.repo),
      ),
    );
  }

  Future<void> _confirm() async {
    // ✅ AI 菜谱前先要求登录
    final ok = await requireLogin(context);
    if (!ok) return;

    final selected = _activeItems.where((item) => _selectedIds.contains(item.id)).toList();

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

              // ===== Archive entry (above inventory) =====
              _SectionCard(
                title: 'Archive',
                subtitle: 'Saved recipes • sorted by time you added them.',
                child: _EntryTile(
                  icon: Icons.archive_outlined,
                  title: 'Open archive',
                  subtitle: 'View your saved recipe ideas',
                  onTap: _openArchive,
                ),
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
                        subtitle: 'Add items first, then generate recipes here.',
                      )
                    : Column(
                        children: _activeItems.map((item) {
                          final selected = _selectedIds.contains(item.id);
                          final days = item.daysToExpiry;
                          final leftText = days >= 999 ? 'no expiry set' : '$days days left';

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
                subtitle: 'Not in inventory but you plan to use today (e.g. rice, noodles, sauces).',
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
                        subtitle: 'Optional — add staples to help AI complete dishes.',
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
                      subtitle: 'Use this only for fresh ingredients you want to track (not condiments).',
                      onChanged: (v) => setState(() => _addExtrasToInventory = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ===== Special request =====
              _SectionCard(
                title: 'Special request',
                subtitle: 'Diet preferences or style, e.g. “vegan”, “no peanuts”, “Chinese style”, “high protein”…',
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

// ================== Archive page ==================

class RecipeArchivePage extends StatefulWidget {
  final InventoryRepository repo;

  const RecipeArchivePage({
    super.key,
    required this.repo,
  });

  @override
  State<RecipeArchivePage> createState() => _RecipeArchivePageState();
}

class _RecipeArchivePageState extends State<RecipeArchivePage> {
  List<RecipeArchiveEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await RecipeArchiveStore.load();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _removeOne(String id) async {
    await RecipeArchiveStore.remove(id);
    await _reload();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Clear archive?'),
          content: const Text('This will remove all archived recipes from this device.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
          ],
        );
      },
    );
    if (ok == true) {
      await RecipeArchiveStore.clear();
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF6F8FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Archive'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.black.withOpacity(0.06)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 16,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.archive_outlined,
                                  size: 28,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No archived recipes',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Open a recipe and tap “Add to archive”.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: FilledButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Back'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final e = _items[index];
                      final r = e.recipe;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ArchiveRecipeCard(
                          title: r.title,
                          subtitle: '${r.timeLabel} • ${r.appliancesLabel}',
                          addedAt: e.addedAt,
                          onOpen: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecipeDetailPage(
                                  recipe: r,
                                  repo: widget.repo,
                                  usedItems: const [],
                                  onInventoryUpdated: null,
                                ),
                              ),
                            );
                          },
                          onRemove: () => _removeOne(r.id),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}


class _ArchiveRecipeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime addedAt;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _ArchiveRecipeCard({
    required this.title,
    required this.subtitle,
    required this.addedAt,
    required this.onOpen,
    required this.onRemove,
  });

  String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.fastfood),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Added: ${_fmt(addedAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
            ),
            IconButton(
              onPressed: onOpen,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Open',
            ),
          ],
        ),
      ),
    );
  }
}

// ================== 通用 entry tile ==================

class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.03),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, color: Colors.grey[700]),
            ],
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
                  color: selected ? Theme.of(context).colorScheme.primary : Colors.black.withOpacity(0.05),
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

  /// e.g. "20 min"
  final String timeLabel;

  final int expiringCount;

  final List<String> ingredients;
  final List<String> steps;

  /// 🆕 厨具/家电（例如 ["Oven","Pan"]），用于 pills & HC actions
  final List<String> appliances;

  /// 🆕 可选：烤箱预热温度（摄氏度）
  final int? ovenTempC;

  final String? description;
  final String? imageUrl;

  RecipeSuggestion({
    required this.id,
    required this.title,
    required this.timeLabel,
    required this.expiringCount,
    required this.ingredients,
    required this.steps,
    this.appliances = const [],
    this.ovenTempC,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'timeLabel': timeLabel,
        'expiringCount': expiringCount,
        'ingredients': ingredients,
        'steps': steps,
        'appliances': appliances,
        'ovenTempC': ovenTempC,
        'description': description,
        'imageUrl': imageUrl,
      };

  static RecipeSuggestion fromJson(Map<String, dynamic> m) {
    final appliancesRaw = m['appliances'];
    final appliances = (appliancesRaw is List)
        ? appliancesRaw.map((x) => x.toString()).toList()
        : const <String>[];

    int? ovenTempC;
    final v = m['ovenTempC'];
    if (v is int) {
      ovenTempC = v;
    } else if (v is num) {
      ovenTempC = v.round();
    } else if (v != null) {
      ovenTempC = int.tryParse(v.toString());
    }

    return RecipeSuggestion(
      id: m['id']?.toString() ?? const Uuid().v4(),
      title: (m['title'] ?? 'Untitled').toString(),
      timeLabel: (m['timeLabel'] ?? '20 min').toString(),
      expiringCount: (m['expiringCount'] ?? 0) is int
          ? (m['expiringCount'] ?? 0) as int
          : int.tryParse((m['expiringCount'] ?? '0').toString()) ?? 0,
      ingredients: (m['ingredients'] as List<dynamic>? ?? const []).map((x) => x.toString()).toList(),
      steps: (m['steps'] as List<dynamic>? ?? const []).map((x) => x.toString()).toList(),
      appliances: appliances,
      ovenTempC: ovenTempC,
      description: m['description']?.toString(),
      imageUrl: m['imageUrl']?.toString(),
    );
  }

  bool get usesOven {
    final a = appliances.map((x) => x.toLowerCase()).toList();
    if (a.any((x) => x.contains('oven'))) return true;

    // fallback: steps/title heuristic
    final text = ('${title}\n${steps.join('\n')}').toLowerCase();
    return text.contains('oven') || text.contains('preheat') || text.contains('bake');
  }

  int? inferOvenTempFromText() {
    // try appliances-provided first
    if (ovenTempC != null) return ovenTempC;

    // Find patterns like "200°C" / "200 C" / "200 degrees"
    final text = ('${title}\n${steps.join('\n')}').toLowerCase();
    final reg = RegExp(r'(\d{2,3})\s*(°\s*c|°c|c\b|degrees?\s*c)');
    final m = reg.firstMatch(text);
    if (m != null) {
      final v = int.tryParse(m.group(1) ?? '');
      if (v != null && v >= 50 && v <= 300) return v;
    }

    // common fallback: "preheat the oven" without temp
    return null;
  }

  String get appliancesLabel {
    if (appliances.isEmpty) return 'No tools';
    if (appliances.length == 1) return appliances.first;
    return '${appliances.first} +${appliances.length - 1}';
  }
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
  static const String _backendBase = 'https://project-study-bsh.vercel.app';

  int _state = 0; // 0 配置, 1 loading, 2 结果
  List<RecipeSuggestion> _recipes = [];

  Future<void> _generate() async {
    setState(() => _state = 1);

    try {
      final ingredients = widget.items.map((i) => '${i.name} (${i.quantity} ${i.unit})').toList();

      final uri = Uri.parse('$_backendBase/api/recipe');

      final body = <String, dynamic>{
        'ingredients': ingredients,
        'extraIngredients': widget.extraIngredients,
      };

      if (widget.specialRequest != null && widget.specialRequest!.trim().isNotEmpty) {
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

        final appliancesRaw = m['appliances'];
        final appliances = (appliancesRaw is List)
            ? appliancesRaw.map((x) => x.toString()).toList()
            : const <String>[];

        int? ovenTempC;
        for (final k in [
          'ovenTempC',
          'oven_temp_c',
          'ovenTemperatureC',
          'oven_temperature',
          'temperatureC',
        ]) {
          if (m[k] != null) {
            final v = m[k];
            if (v is int) {
              ovenTempC = v;
            } else if (v is num) {
              ovenTempC = v.round();
            } else {
              ovenTempC = int.tryParse(v.toString());
            }
            break;
          }
        }

        return RecipeSuggestion(
          id: m['id']?.toString() ?? const Uuid().v4(),
          title: m['title'] ?? 'Untitled',
          timeLabel: m['timeLabel'] ?? '20 min',
          expiringCount: (m['expiringCount'] ?? 0) is int
              ? (m['expiringCount'] ?? 0) as int
              : int.tryParse((m['expiringCount'] ?? '0').toString()) ?? 0,
          ingredients: (m['ingredients'] as List<dynamic>? ?? const []).map((x) => x.toString()).toList(),
          steps: (m['steps'] as List<dynamic>? ?? const []).map((x) => x.toString()).toList(),
          appliances: appliances,
          ovenTempC: ovenTempC,
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
          subtitle: 'We prioritize expiring items first, and use extra ingredients to complete dishes.',
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
                  children: widget.items.map((i) => Chip(label: Text(i.name))).toList(),
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
                  children: widget.extraIngredients.map((e) => Chip(label: Text(e))).toList(),
                ),
                const SizedBox(height: 14),
              ],
              if (widget.specialRequest != null && widget.specialRequest!.trim().isNotEmpty) ...[
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
              childAspectRatio: 0.62,
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

  IconData _toolIcon(String label) {
    final t = label.toLowerCase();
    if (t.contains('oven')) return Icons.local_fire_department;
    if (t.contains('pan') || t.contains('wok')) return Icons.soup_kitchen;
    if (t.contains('pot')) return Icons.outdoor_grill;
    return Icons.handyman_outlined;
  }

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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _InfoPill(
                        icon: Icons.schedule,
                        text: recipe.timeLabel,
                        bg: Colors.black.withOpacity(0.06),
                        fg: Colors.grey.shade800,
                      ),
                      _InfoPill(
                        icon: _toolIcon(recipe.appliancesLabel),
                        text: recipe.appliancesLabel,
                        bg: Colors.black.withOpacity(0.06),
                        fg: Colors.grey.shade800,
                      ),
                    ],
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

class RecipeDetailPage extends StatefulWidget {
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
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  static const String _backendBase = 'https://project-study-bsh.vercel.app';

  bool _hcActionLoading = false;
  bool _archiving = false;

  Future<String?> _getSupabaseAccessTokenOrNull() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    return session?.accessToken;
  }

  Future<void> _addToArchive() async {
    setState(() => _archiving = true);
    try {
      await RecipeArchiveStore.add(widget.recipe);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to archive ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add to archive failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  Future<int?> _askTempC(BuildContext context, {int? initial}) async {
    final c = TextEditingController(
      text: initial != null ? initial.toString() : '',
    );
    final v = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Oven temperature'),
          content: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'e.g. 200',
              suffixText: '°C',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final n = int.tryParse(c.text.trim());
                Navigator.pop(ctx, n);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return v;
  }

  Future<String> _findOvenHaId(String token) async {
    final r = await http.get(
      Uri.parse('$_backendBase/api/hc/appliances'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    final text = r.body;
    if (r.statusCode != 200) {
      throw Exception('Fetch appliances failed: ${r.statusCode} $text');
    }
    final obj = jsonDecode(text) as Map<String, dynamic>;
    final list = (obj['homeappliances'] as List<dynamic>? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    Map<String, dynamic>? oven;
    for (final a in list) {
      final t = (a['type'] ?? '').toString().toLowerCase();
      final name = (a['name'] ?? '').toString().toLowerCase();
      if (t == 'oven' || name.contains('oven')) {
        oven = a;
        break;
      }
    }
    if (oven == null) {
      throw Exception('No oven appliance found in Home Connect.');
    }
    final haId = oven['haId']?.toString();
    if (haId == null || haId.isEmpty) {
      throw Exception('Oven haId missing.');
    }
    return haId;
  }

  Future<void> _preheatOven() async {
    // ✅ HC action 前也要求登录
    final ok = await requireLogin(context);
    if (!ok) return;

    final token = await _getSupabaseAccessTokenOrNull();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in.')),
      );
      return;
    }

    int? temp = widget.recipe.ovenTempC ?? widget.recipe.inferOvenTempFromText();
    if (temp == null) {
      temp = await _askTempC(context);
      if (temp == null) return;
    }

    setState(() => _hcActionLoading = true);
    try {
      final haId = await _findOvenHaId(token);

      final r = await http.post(
        Uri.parse('$_backendBase/api/hc/oven/preheat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'haId': haId,
          'temperatureC': temp,
          'programKey': 'Cooking.Oven.Program.HeatingMode.PreHeating',
        }),
      );

      if (r.statusCode != 200) {
        throw Exception('Preheat failed: ${r.statusCode} ${r.body}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oven preheating to $temp°C ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preheat oven failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _hcActionLoading = false);
    }
  }

  IconData _toolIcon(String label) {
    final t = label.toLowerCase();
    if (t.contains('oven')) return Icons.local_fire_department;
    if (t.contains('pan') || t.contains('wok')) return Icons.soup_kitchen;
    if (t.contains('pot')) return Icons.outdoor_grill;
    return Icons.handyman_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = const Color(0xFFF6F8FA);
    final recipe = widget.recipe;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            onPressed: _archiving ? null : _addToArchive,
            icon: _archiving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.archive_outlined),
            tooltip: 'Add to archive',
          ),
        ],
      ),
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
                icon: _toolIcon(recipe.appliancesLabel),
                text: recipe.appliancesLabel,
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

          if (recipe.usesOven) ...[
            _InfoCard(
              title: 'Cook with this',
              icon: Icons.electrical_services_outlined,
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.local_fire_department,
                    title: 'Preheat oven',
                    subtitle: (recipe.ovenTempC ?? recipe.inferOvenTempFromText()) != null
                        ? 'Preheat to ${(recipe.ovenTempC ?? recipe.inferOvenTempFromText())}°C'
                        : 'Choose a temperature and start preheating',
                    loading: _hcActionLoading,
                    onTap: _hcActionLoading ? null : _preheatOven,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Requires Home Connect binding.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          _InfoCard(
            title: 'Archive',
            icon: Icons.archive_outlined,
            child: _ActionTile(
              icon: Icons.archive_outlined,
              title: 'Add to archive',
              subtitle: 'Save this recipe for later',
              loading: _archiving,
              onTap: _archiving ? null : _addToArchive,
            ),
          ),

          const SizedBox(height: 12),

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

          if (widget.usedItems.isNotEmpty)
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
                  for (final item in widget.usedItems) {
                    await widget.repo.recordImpactForAction(item, 'eat');
                    await widget.repo.updateStatus(item.id, FoodStatus.consumed);
                  }
                  widget.onInventoryUpdated?.call();
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.black.withOpacity(0.03),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Icon(Icons.chevron_right, color: Colors.grey[700]),
            ],
          ),
        ),
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
