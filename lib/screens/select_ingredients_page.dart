// lib/screens/select_ingredients_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../utils/auth_guard.dart';

// ================== Global UI Constants ==================

const String _kRecipeArchiveKey = 'recipe_archive_v1';

class AppStyle {
  static const Color bg = Color(0xFFF4F6F9);
  static const Color primary = Color(0xFF005F87);
  static const Color cardColor = Colors.white;
  static const double cardRadius = 20.0;
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

// ================== Recipe Archive Logic ==================

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
      list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(RecipeSuggestion recipe) async {
    final sp = await SharedPreferences.getInstance();
    final list = await load();
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

// ================== Main Page: Select Ingredients ==================

class SelectIngredientsPage extends StatefulWidget {
  final InventoryRepository repo;
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
  final TextEditingController _specialRequestController = TextEditingController();
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _activeItems = widget.repo.getActiveItems();
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
      MaterialPageRoute(builder: (_) => RecipeArchivePage(repo: widget.repo)),
    );
  }

  Future<void> _confirm() async {
    final ok = await requireLogin(context);
    if (!ok) return;

    final selected = _activeItems.where((item) => _selectedIds.contains(item.id)).toList();
    final requestText = _specialRequestController.text.trim();
    final special = requestText.isEmpty ? null : requestText;

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
    final selectedCount = _selectedIds.length;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppStyle.bg,
        appBar: AppBar(
          title: const Text('Choose ingredients', style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: AppStyle.bg,
          elevation: 0,
          centerTitle: false,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _HeroCard(
                selectedCount: selectedCount,
                preselectedCount: widget.preselectedExpiring.length,
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Archive',
                subtitle: 'View saved recipe ideas',
                child: _EntryTile(
                  icon: Icons.bookmark_outline,
                  title: 'Open Recipe Archive',
                  subtitle: 'Your saved collection',
                  onTap: _openArchive,
                ),
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'From Inventory',
                subtitle: _activeItems.isEmpty ? null : 'Select items to use in today\'s recipe.',
                child: _activeItems.isEmpty
                    ? _EmptyHint(
                        icon: Icons.inventory_2_outlined,
                        title: 'Inventory is empty',
                        subtitle: 'Add items first, then generate recipes here.',
                      )
                    : Column(
                        children: _activeItems.map((item) {
                          final selected = _selectedIds.contains(item.id);
                          final days = item.daysToExpiry;
                          final leftText = days >= 999 ? 'No expiry' : '$days days left';
                          final urgency = days >= 999
                              ? _Urgency.neutral
                              : days <= 1 ? _Urgency.high : days <= 3 ? _Urgency.medium : _Urgency.low;

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
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Additional Ingredients',
                subtitle: 'Staples not in inventory (e.g. rice, oil, spices).',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InputRow(
                      controller: _extraController,
                      hintText: 'Add an ingredient...',
                      onSubmit: _addExtraIngredient,
                      onAdd: _addExtraIngredient,
                    ),
                    const SizedBox(height: 12),
                    if (_extraIngredients.isEmpty)
                      _EmptyHint(
                        icon: Icons.kitchen_outlined,
                        title: 'No extras added',
                        subtitle: 'Optional ingredients to help AI.',
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _extraIngredients.map((e) => Chip(
                          label: Text(e, style: const TextStyle(fontSize: 13)),
                          backgroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onDeleted: () => _removeExtraIngredient(e),
                        )).toList(),
                      ),
                    const SizedBox(height: 16),
                    _ToggleRow(
                      value: _addExtrasToInventory,
                      title: 'Add to Inventory',
                      subtitle: 'Save these new items to your stock list.',
                      onChanged: (v) => setState(() => _addExtrasToInventory = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Special Preferences',
                subtitle: 'E.g., "Vegan", "High protein", "Spicy Sichuan style".',
                child: TextField(
                  controller: _specialRequestController,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Any specific requests?',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
              ],
            ),
            child: _GradientPrimaryButton(
              onTap: _confirm,
              icon: Icons.auto_awesome,
              title: 'Generate Recipes',
              subtitle: selectedCount == 0 ? 'Select items to start' : 'Using $selectedCount items',
              enabled: selectedCount > 0 || _extraIngredients.isNotEmpty,
            ),
          ),
        ),
      ),
    );
  }
}

// ================== Archive Page ==================

class RecipeArchivePage extends StatefulWidget {
  final InventoryRepository repo;
  const RecipeArchivePage({super.key, required this.repo});

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
    await Future.delayed(const Duration(milliseconds: 300));
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
          content: const Text('This will remove all archived recipes.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear All')),
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
    return Scaffold(
      backgroundColor: AppStyle.bg,
      appBar: AppBar(
        title: const Text('Saved Recipes', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppStyle.bg,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            IconButton(onPressed: _clearAll, icon: const Icon(Icons.delete_outline, color: Colors.grey)),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (ctx, i) => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: _ShimmerArchiveCard(),
                ),
              )
            : _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: AppStyle.softShadow,
                            ),
                            child: Icon(Icons.bookmark_border, size: 48, color: Colors.grey.shade300),
                          ),
                          const SizedBox(height: 24),
                          const Text('No recipes saved yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
                          const SizedBox(height: 8),
                          Text('Generate recipes and tap the archive icon to save them here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, height: 1.5)),
                          const SizedBox(height: 32),
                          FilledButton.tonal(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final e = _items[index];
                      final r = e.recipe;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ArchiveRecipeCard(
                          // ✅ 修正点：之前这里传了 title/subtitle，现在直接传 recipe 对象
                          recipe: r,
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

// ================== Generator Page ==================

class RecipeGeneratorSheet extends StatefulWidget {
  final InventoryRepository repo;
  final List<FoodItem> items;
  final List<String> extraIngredients;
  final String? specialRequest;
  final VoidCallback? onInventoryUpdated;

  const RecipeGeneratorSheet({super.key, required this.repo, required this.items, required this.extraIngredients, this.specialRequest, this.onInventoryUpdated});

  @override
  State<RecipeGeneratorSheet> createState() => _RecipeGeneratorSheetState();
}

class _RecipeGeneratorSheetState extends State<RecipeGeneratorSheet> {
  static const String _backendBase = 'https://project-study-bsh.vercel.app';
  int _state = 0;
  List<RecipeSuggestion> _recipes = [];

  Future<void> _generate() async {
    setState(() => _state = 1);
    try {
      final ingredients = widget.items.map((i) => '${i.name} (${i.quantity} ${i.unit})').toList();
      final uri = Uri.parse('$_backendBase/api/recipe');
      final body = <String, dynamic>{'ingredients': ingredients, 'extraIngredients': widget.extraIngredients};
      if (widget.specialRequest != null && widget.specialRequest!.trim().isNotEmpty) body['specialRequest'] = widget.specialRequest!.trim();

      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      if (resp.statusCode != 200) throw Exception('Server error: ${resp.statusCode} - ${resp.body}');

      final root = jsonDecode(resp.body);
      List<dynamic> rawList = (root is Map<String, dynamic> && root['recipes'] is List) ? root['recipes'] : (root is List ? root : []);

      _recipes = rawList.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return RecipeSuggestion.fromJson(m);
      }).toList();

      if (!mounted) return;
      setState(() => _state = 2);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = 0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI recipe failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bg,
      appBar: AppBar(backgroundColor: AppStyle.bg, title: const Text('AI Chef', style: TextStyle(fontWeight: FontWeight.w700)), centerTitle: false, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _state == 0 ? _buildConfig() : _state == 1 ? _buildLoading() : _buildResult(),
        ),
      ),
    );
  }

  Widget _buildConfig() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(title: 'Review Selection', subtitle: 'AI will prioritize these expiring items.', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.items.isEmpty) _EmptyHint(icon: Icons.info_outline, title: 'No Items', subtitle: 'Please select ingredients first.')
        else Wrap(spacing: 8, runSpacing: 8, children: widget.items.map((i) => Chip(label: Text(i.name), backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300))).toList()),
        if (widget.extraIngredients.isNotEmpty) ...[const SizedBox(height: 16), const Text('Extras', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: widget.extraIngredients.map((e) => Chip(label: Text(e), backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300))).toList())],
        if (widget.specialRequest != null && widget.specialRequest!.trim().isNotEmpty) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(children: [const Icon(Icons.star, color: Colors.orange, size: 18), const SizedBox(width: 8), Expanded(child: Text('Note: ${widget.specialRequest!}', style: TextStyle(color: Colors.brown.shade700)))],),)],
      ])),
      const Spacer(),
      _GradientPrimaryButton(onTap: _generate, icon: Icons.auto_awesome, title: 'Start Generating', subtitle: 'Create personalized recipes', enabled: true),
    ]);
  }

  Widget _buildLoading() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ShimmerBlock(width: 180, height: 24),
      const SizedBox(height: 16),
      Expanded(child: GridView.builder(itemCount: 4, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.75), itemBuilder: (context, index) => const _ShimmerRecipeCard())),
    ]);
  }

  Widget _buildResult() {
    if (_recipes.isEmpty) return const Center(child: Text('No recipes generated.'));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Suggestions for you', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20))),
      Expanded(child: GridView.builder(itemCount: _recipes.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.75), itemBuilder: (context, index) {
        final recipe = _recipes[index];
        return _RecipeCard(recipe: recipe, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: recipe, repo: widget.repo, usedItems: widget.items, onInventoryUpdated: widget.onInventoryUpdated))));
      })),
    ]);
  }
}

// ================== Detail Page ==================

class RecipeDetailPage extends StatefulWidget {
  final RecipeSuggestion recipe;
  final InventoryRepository repo;
  final List<FoodItem> usedItems;
  final VoidCallback? onInventoryUpdated;
  const RecipeDetailPage({super.key, required this.recipe, required this.repo, required this.usedItems, this.onInventoryUpdated});
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to archive ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add to archive failed: $e')));
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  Future<int?> _askTempC(BuildContext context, {int? initial}) async {
    final c = TextEditingController(text: initial != null ? initial.toString() : '');
    return showDialog<int?>(context: context, builder: (ctx) => AlertDialog(title: const Text('Oven temperature'), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'e.g. 200', suffixText: '°C')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')), TextButton(onPressed: () {final n = int.tryParse(c.text.trim()); Navigator.pop(ctx, n);}, child: const Text('OK'))]));
  }

  Future<String> _findOvenHaId(String token) async {
    final r = await http.get(Uri.parse('$_backendBase/api/hc/appliances'), headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
    if (r.statusCode != 200) throw Exception('Fetch appliances failed: ${r.statusCode} ${r.body}');
    final obj = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (obj['homeappliances'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    for (final a in list) { if ((a['type'] ?? '').toString().toLowerCase() == 'oven' || (a['name'] ?? '').toString().toLowerCase().contains('oven')) return a['haId'].toString(); }
    throw Exception('No oven appliance found');
  }

  Future<void> _preheatOven() async {
    final ok = await requireLogin(context); if (!ok) return;
    final token = await _getSupabaseAccessTokenOrNull(); if (token == null) return;
    int? temp = widget.recipe.ovenTempC ?? widget.recipe.inferOvenTempFromText();
    if (temp == null) { temp = await _askTempC(context); if (temp == null) return; }
    setState(() => _hcActionLoading = true);
    try {
      final haId = await _findOvenHaId(token);
      final r = await http.post(Uri.parse('$_backendBase/api/hc/oven/preheat'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'haId': haId, 'temperatureC': temp, 'programKey': 'Cooking.Oven.Program.HeatingMode.PreHeating'}));
      if (r.statusCode != 200) throw Exception('Failed: ${r.body}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Oven preheating to $temp°C ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preheat failed: $e')));
    } finally {
      if (mounted) setState(() => _hcActionLoading = false);
    }
  }

  IconData _toolIcon(String label) {
    if (label.toLowerCase().contains('oven')) return Icons.local_fire_department_rounded;
    return Icons.handyman_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return Scaffold(
      backgroundColor: AppStyle.bg,
      appBar: AppBar(title: const Text('Recipe Details', style: TextStyle(fontWeight: FontWeight.w700)), backgroundColor: AppStyle.bg, elevation: 0, actions: [IconButton(onPressed: _archiving ? null : _addToArchive, icon: const Icon(Icons.bookmark_outline))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        Hero(
          tag: 'recipe_img_${recipe.id}', 
          child: Container(
            height: 180, width: double.infinity,
            decoration: BoxDecoration(color: AppStyle.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
            child: const Center(child: Icon(Icons.fastfood_rounded, size: 64, color: AppStyle.primary)),
          ),
        ),
        const SizedBox(height: 20),
        Text(recipe.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [_InfoPill(icon: Icons.schedule, text: recipe.timeLabel, bg: Colors.grey.shade200, fg: Colors.black87), _InfoPill(icon: _toolIcon(recipe.appliancesLabel), text: recipe.appliancesLabel, bg: Colors.grey.shade200, fg: Colors.black87)]),
        const SizedBox(height: 24),
        if (recipe.description != null) ...[Text(recipe.description!, style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 15)), const SizedBox(height: 24)],
        if (recipe.usesOven) ...[Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade100)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.smart_toy_outlined, color: Colors.deepOrange), SizedBox(width: 8), Text('Smart Kitchen', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange))]), const SizedBox(height: 12), _ActionTile(icon: Icons.local_fire_department_rounded, title: 'Preheat Oven', subtitle: 'Tap to start', loading: _hcActionLoading, onTap: _hcActionLoading ? null : _preheatOven, bgColor: Colors.white)]))],
        const SizedBox(height: 24),
        _SectionCard(title: 'Ingredients', child: Column(children: recipe.ingredients.map((ing) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: AppStyle.primary)), const SizedBox(width: 12), Expanded(child: Text(ing, style: const TextStyle(fontSize: 15, height: 1.4)))]))).toList())),
        const SizedBox(height: 24),
        _SectionCard(title: 'Instructions', child: Column(children: recipe.steps.asMap().entries.map((e) => Container(margin: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: AppStyle.primary.withOpacity(0.1), shape: BoxShape.circle), child: Text('${e.key + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppStyle.primary))), const SizedBox(width: 12), Expanded(child: Text(e.value, style: const TextStyle(height: 1.5, fontSize: 15)))]))).toList())),
        const SizedBox(height: 32),
        if (widget.usedItems.isNotEmpty) SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: () async {
          final shouldUpdate = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Finished Cooking?'), content: const Text('Update inventory?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update'))]));
          if (shouldUpdate == true) {
            for (final item in widget.usedItems) { await widget.repo.recordImpactForAction(item, 'eat'); await widget.repo.updateStatus(item.id, FoodStatus.consumed); }
            widget.onInventoryUpdated?.call();
            if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventory updated ✅'))); Navigator.pop(context); }
          }
        }, icon: const Icon(Icons.check_circle_outline), label: const Text('I Cooked This'), style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
      ]),
    );
  }
}

// ================== Helper Widgets & Models ==================

// ✅ 修正：_ArchiveRecipeCard 现在接受 RecipeSuggestion 对象而不是 title/subtitle
class _ArchiveRecipeCard extends StatelessWidget {
  final RecipeSuggestion recipe;
  final DateTime addedAt;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _ArchiveRecipeCard({
    required this.recipe,
    required this.addedAt,
    required this.onOpen,
    required this.onRemove,
  });

  String _fmt(DateTime t) {
    return '${t.year}-${t.month}-${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppStyle.softShadow,
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Hero(
                tag: 'recipe_icon_${recipe.id}',
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppStyle.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded, color: AppStyle.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${recipe.timeLabel} • ${recipe.appliancesLabel}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved on ${_fmt(addedAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RecipeSuggestion recipe;
  final VoidCallback onTap;
  const _RecipeCard({required this.recipe, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppStyle.softShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Hero(
            tag: 'recipe_img_${recipe.id}', 
            child: Container(
              height: 100, width: double.infinity, 
              decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), color: Color(0xFFF0F5FF)),
              child: Stack(children: [
                Center(child: Icon(Icons.fastfood_rounded, size: 40, color: AppStyle.primary.withOpacity(0.3))),
                if (recipe.expiringCount > 0) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.eco, color: Colors.white, size: 10), const SizedBox(width: 4), Text('Uses ${recipe.expiringCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]))),
              ]),
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2)),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.schedule, size: 14, color: Colors.grey.shade500), const SizedBox(width: 4), Text(recipe.timeLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
          ])),
        ]),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;
  const _InfoPill({required this.icon, required this.text, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: fg), const SizedBox(width: 6), Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)))]));
  }
}

class _ShimmerRecipeCard extends StatefulWidget { const _ShimmerRecipeCard(); @override State<_ShimmerRecipeCard> createState() => _ShimmerRecipeCardState(); }
class _ShimmerRecipeCardState extends State<_ShimmerRecipeCard> with SingleTickerProviderStateMixin { late AnimationController _controller; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _controller, builder: (context, child) { final color = Color.lerp(Colors.grey[200], Colors.grey[100], _controller.value); return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppStyle.softShadow), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 100, width: double.infinity, decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), color: color)), Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 6), Container(width: 100, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 12), Row(children: [Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Container(width: 60, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))]),],),),],),); },); } }
class _ShimmerArchiveCard extends StatefulWidget { const _ShimmerArchiveCard(); @override State<_ShimmerArchiveCard> createState() => _ShimmerArchiveCardState(); }
class _ShimmerArchiveCardState extends State<_ShimmerArchiveCard> with SingleTickerProviderStateMixin { late AnimationController _controller; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _controller, builder: (context, child) { final color = Color.lerp(Colors.grey[200], Colors.grey[100], _controller.value); return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppStyle.softShadow), padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16))), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 8), Container(width: 120, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))]))])); },); } }
class _ShimmerBlock extends StatefulWidget { final double width; final double height; const _ShimmerBlock({required this.width, required this.height}); @override State<_ShimmerBlock> createState() => _ShimmerBlockState(); }
class _ShimmerBlockState extends State<_ShimmerBlock> with SingleTickerProviderStateMixin { late AnimationController _controller; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _controller, builder: (context, child) { final color = Color.lerp(Colors.grey[300], Colors.grey[100], _controller.value); return Container(width: widget.width, height: widget.height, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))); },); } }

class _InputRow extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onAdd;
  final VoidCallback onSubmit;
  const _InputRow({required this.controller, required this.hintText, required this.onAdd, required this.onSubmit});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: SizedBox(height: 48, child: TextField(
        controller: controller,
        textInputAction: TextInputAction.done, 
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(hintText: hintText, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), contentPadding: const EdgeInsets.symmetric(horizontal: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppStyle.primary)), filled: true, fillColor: Colors.white),
      ))),
      const SizedBox(width: 8),
      SizedBox(height: 48, width: 48, child: FilledButton(style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: AppStyle.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: onAdd, child: const Icon(Icons.add_rounded))),
    ]);
  }
}

class _ToggleRow extends StatelessWidget { final bool value; final String title; final String subtitle; final ValueChanged<bool> onChanged; const _ToggleRow({required this.value, required this.title, required this.subtitle, required this.onChanged}); @override Widget build(BuildContext context) { return InkWell(onTap: () => onChanged(!value), borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: value ? AppStyle.primary.withOpacity(0.05) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: value ? AppStyle.primary.withOpacity(0.2) : Colors.transparent)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: value ? AppStyle.primary : Colors.black87)), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600]))])), Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppStyle.primary)]))); } }
class _EmptyHint extends StatelessWidget { final IconData icon; final String title; final String subtitle; const _EmptyHint({required this.icon, required this.title, required this.subtitle}); @override Widget build(BuildContext context) { return Container(padding: const EdgeInsets.all(20), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200, width: 1, style: BorderStyle.solid)), child: Column(children: [Icon(icon, color: Colors.grey.shade400, size: 32), const SizedBox(height: 8), Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))])); } }
class _GradientPrimaryButton extends StatelessWidget { final VoidCallback onTap; final IconData icon; final String title; final String subtitle; final bool enabled; const _GradientPrimaryButton({required this.onTap, required this.icon, required this.title, required this.subtitle, required this.enabled}); @override Widget build(BuildContext context) { return AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: enabled ? 1 : 0.6, child: Material(color: Colors.transparent, child: InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(16), child: Container(height: 60, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF005F87), Color(0xFF0079AD)]), borderRadius: BorderRadius.circular(16), boxShadow: [if (enabled) const BoxShadow(color: Color(0x40005F87), blurRadius: 12, offset: Offset(0, 4))]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 22), const SizedBox(width: 12), Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)), Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500))])]))))); } }
class _EntryTile extends StatelessWidget { final IconData icon; final String title; final String subtitle; final VoidCallback onTap; const _EntryTile({required this.icon, required this.title, required this.subtitle, required this.onTap}); @override Widget build(BuildContext context) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppStyle.cardRadius), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF0F5FF), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppStyle.primary)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600]))])), Icon(Icons.chevron_right_rounded, color: Colors.grey[400])]))); } }
class _SectionCard extends StatelessWidget { final String title; final String? subtitle; final Widget child; const _SectionCard({required this.title, this.subtitle, required this.child}); @override Widget build(BuildContext context) { return Container(decoration: BoxDecoration(color: AppStyle.cardColor, borderRadius: BorderRadius.circular(AppStyle.cardRadius), boxShadow: AppStyle.softShadow), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.3))]])), const SizedBox(height: 12), Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child)])); } }
class _HeroCard extends StatelessWidget { final int selectedCount; final int preselectedCount; const _HeroCard({required this.selectedCount, required this.preselectedCount}); @override Widget build(BuildContext context) { return Container(height: 150, decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF005F87), Color(0xFF0082B8)]), boxShadow: const [BoxShadow(color: Color(0x33005F87), blurRadius: 20, offset: Offset(0, 10))]), child: Stack(children: [Positioned(right: -20, top: -20, child: Icon(Icons.restaurant_menu, size: 140, color: Colors.white.withOpacity(0.1))), Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text('$selectedCount', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800, height: 1.0)), const SizedBox(width: 8), const Text('items selected', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))]), const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.info_outline, size: 14, color: Colors.white), const SizedBox(width: 6), Text(preselectedCount > 0 ? '$preselectedCount items expiring soon' : 'Pick items to cook', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))]))]))])); } }
enum _Urgency { high, medium, low, neutral }
class _InventoryPickTile extends StatelessWidget { final String name; final String qtyText; final String expiryText; final _Urgency urgency; final bool selected; final VoidCallback onTap; const _InventoryPickTile({required this.name, required this.qtyText, required this.expiryText, required this.urgency, required this.selected, required this.onTap}); Color _badgeColor() { switch (urgency) { case _Urgency.high: return Colors.red; case _Urgency.medium: return Colors.orange; case _Urgency.low: return Colors.green; case _Urgency.neutral: return Colors.grey; } } @override Widget build(BuildContext context) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: selected ? AppStyle.primary.withOpacity(0.04) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? AppStyle.primary : Colors.grey.shade200, width: selected ? 1.5 : 1)), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: _badgeColor(), shape: BoxShape.circle)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: selected ? AppStyle.primary : Colors.black87)), const SizedBox(height: 2), Text('$qtyText • $expiryText', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])), Container(width: 24, height: 24, decoration: BoxDecoration(color: selected ? AppStyle.primary : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: selected ? AppStyle.primary : Colors.grey.shade300, width: 1.5)), child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null)]))); } }
class _ActionTile extends StatelessWidget { final IconData icon; final String title; final String subtitle; final bool loading; final VoidCallback? onTap; final Color bgColor; const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.loading, required this.onTap, this.bgColor = const Color(0xFFF5F7FA)}); @override Widget build(BuildContext context) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: AppStyle.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppStyle.primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600]))])), if (loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(Icons.chevron_right, color: Colors.grey[400])]))); } }

class RecipeSuggestion {
  final String id;
  final String title;
  final String timeLabel;
  final int expiringCount;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> appliances;
  final int? ovenTempC;
  final String? description;
  final String? imageUrl;

  RecipeSuggestion({required this.id, required this.title, required this.timeLabel, required this.expiringCount, required this.ingredients, required this.steps, this.appliances = const [], this.ovenTempC, this.description, this.imageUrl});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'timeLabel': timeLabel, 'expiringCount': expiringCount, 'ingredients': ingredients, 'steps': steps, 'appliances': appliances, 'ovenTempC': ovenTempC, 'description': description, 'imageUrl': imageUrl};

  static RecipeSuggestion fromJson(Map<String, dynamic> m) {
    final appliancesRaw = m['appliances'];
    final appliances = (appliancesRaw is List) ? appliancesRaw.map((x) => x.toString()).toList() : const <String>[];
    int? ovenTempC;
    final v = m['ovenTempC'];
    if (v is int) ovenTempC = v; else if (v is num) ovenTempC = v.round(); else if (v != null) ovenTempC = int.tryParse(v.toString());

    return RecipeSuggestion(
      id: m['id']?.toString() ?? const Uuid().v4(),
      title: (m['title'] ?? 'Untitled').toString(),
      timeLabel: (m['timeLabel'] ?? '20 min').toString(),
      expiringCount: int.tryParse(m['expiringCount']?.toString() ?? '0') ?? 0,
      ingredients: (m['ingredients'] as List? ?? []).map((x) => x.toString()).toList(),
      steps: (m['steps'] as List? ?? []).map((x) => x.toString()).toList(),
      appliances: appliances,
      ovenTempC: ovenTempC,
      description: m['description']?.toString(),
      imageUrl: m['imageUrl']?.toString(),
    );
  }

  bool get usesOven {
    final a = appliances.map((x) => x.toLowerCase()).toList();
    if (a.any((x) => x.contains('oven'))) return true;
    final text = ('${title}\n${steps.join('\n')}').toLowerCase();
    return text.contains('oven') || text.contains('preheat') || text.contains('bake');
  }

  int? inferOvenTempFromText() {
    if (ovenTempC != null) return ovenTempC;
    final text = ('${title}\n${steps.join('\n')}').toLowerCase();
    final reg = RegExp(r'(\d{2,3})\s*(°\s*c|°c|c\b|degrees?\s*c)');
    final m = reg.firstMatch(text);
    if (m != null) {
      final v = int.tryParse(m.group(1) ?? '');
      if (v != null && v >= 50 && v <= 300) return v;
    }
    return null;
  }

  String get appliancesLabel {
    if (appliances.isEmpty) return 'No tools';
    if (appliances.length == 1) return appliances.first;
    return '${appliances.first} +${appliances.length - 1}';
  }
}