// lib/screens/select_ingredients_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../services/archive_service.dart';
import '../utils/auth_guard.dart';

// ================== Global UI Constants ==================

const String _kRecipeArchiveKey = 'recipe_archive_v1';

class AppStyle {
  static const Color primary = Color(0xFF005F87);
  static const double cardRadius = 20.0;
  static Color bg(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
  static Color cardColor(BuildContext context) => Theme.of(context).cardColor;
  static List<BoxShadow> softShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }
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
    await _maybeMigrateLegacy();
    final list = await ArchiveService.instance.getAll();
    return list
        .map((e) => RecipeArchiveEntry(
              recipe: _fromArchived(e),
              addedAt: e.addedAt,
            ))
        .toList();
  }

  static Future<void> add(RecipeSuggestion recipe) async {
    final archived = ArchivedRecipe(
      archiveId: const Uuid().v4(),
      recipeId: recipe.id,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
      title: recipe.title,
      timeLabel: recipe.timeLabel,
      expiringCount: recipe.expiringCount,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
      appliances: recipe.appliances,
      ovenTempC: recipe.ovenTempC,
      description: recipe.description,
      imageUrl: recipe.imageUrl,
    );
    await ArchiveService.instance.add(archived);
  }

  static Future<void> remove(String recipeId) async {
    final list = await ArchiveService.instance.getAll();
    final match = list.firstWhere(
      (e) => e.recipeId == recipeId,
      orElse: () => ArchivedRecipe(
        archiveId: '',
        recipeId: '',
        addedAtMs: 0,
        title: '',
        timeLabel: '',
        expiringCount: 0,
        ingredients: const [],
        steps: const [],
        appliances: const [],
      ),
    );
    if (match.archiveId.isNotEmpty) {
      await ArchiveService.instance.removeByArchiveId(match.archiveId);
    }
  }

  static Future<bool> hasRecipe(String recipeId) async {
    return ArchiveService.instance.containsRecipeId(recipeId);
  }

  static Future<void> clear() async {
    await ArchiveService.instance.clear();
  }

  static Future<void> _maybeMigrateLegacy() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.get(_kRecipeArchiveKey);
    if (raw == null) return;

    try {
      final List<RecipeArchiveEntry> legacy;
      if (raw is String) {
        if (raw.trim().isEmpty) return;
        legacy = (jsonDecode(raw) as List<dynamic>)
            .map((e) => (e as Map).cast<String, dynamic>())
            .map(RecipeArchiveEntry.fromJson)
            .toList();
      } else if (raw is List) {
        legacy = raw
            .whereType<String>()
            .map((e) => jsonDecode(e))
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .map(RecipeArchiveEntry.fromJson)
            .toList();
      } else {
        return;
      }
      for (final entry in legacy) {
        final r = entry.recipe;
        final archived = ArchivedRecipe(
          archiveId: const Uuid().v4(),
          recipeId: r.id,
          addedAtMs: entry.addedAt.millisecondsSinceEpoch,
          title: r.title,
          timeLabel: r.timeLabel,
          expiringCount: r.expiringCount,
          ingredients: r.ingredients,
          steps: r.steps,
          appliances: r.appliances,
          ovenTempC: r.ovenTempC,
          description: r.description,
          imageUrl: r.imageUrl,
        );
        await ArchiveService.instance.add(archived);
      }
      await sp.remove(_kRecipeArchiveKey);
    } catch (_) {
      // ignore legacy parse errors
    }
  }

  static RecipeSuggestion _fromArchived(ArchivedRecipe recipe) {
    return RecipeSuggestion(
      id: recipe.recipeId,
      title: recipe.title,
      timeLabel: recipe.timeLabel,
      expiringCount: recipe.expiringCount,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
      appliances: recipe.appliances,
      ovenTempC: recipe.ovenTempC,
      description: recipe.description,
      imageUrl: recipe.imageUrl,
    );
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

  // 🟢 Settings State
  int _servings = 2;
  bool _isStudentMode = false;

  final TextEditingController _extraController = TextEditingController();
  final TextEditingController _specialRequestController = TextEditingController();
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _activeItems = widget.repo.getActiveItems();
    _sortActiveItems();
    for (final item in widget.preselectedExpiring) {
      _selectedIds.add(item.id);
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isStudentMode = sp.getBool('student_mode') ?? false;
      });
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

  void _updateServings(int delta) {
    setState(() {
      _servings = (_servings + delta).clamp(1, 10);
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
        _sortActiveItems();
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
          servings: _servings,
          studentMode: _isStudentMode,
          onInventoryUpdated: () {
            _hasChanged = true;
            setState(() {
              _activeItems = widget.repo.getActiveItems();
              _sortActiveItems();
            });
          },
        ),
      ),
    );
  }

  void _sortActiveItems() {
    _activeItems.sort((a, b) {
      final aDays = a.daysToExpiry >= 999 ? 99999 : a.daysToExpiry;
      final bDays = b.daysToExpiry >= 999 ? 99999 : b.daysToExpiry;
      return aDays.compareTo(bDays);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIds.length;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppStyle.bg(context),
        appBar: AppBar(
          title: Text(
            'Choose ingredients',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          backgroundColor: AppStyle.bg(context),
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

              if (_isStudentMode) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.indigo.shade400, Colors.indigo.shade600]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Student Mode Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Prioritizing cheap, fast & easy recipes.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _SectionCard(
                title: 'Cooking Settings',
                child: Row(
                  children: [
                    Icon(Icons.people_outline, color: colors.onSurface.withOpacity(0.6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Number of People',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            'Adjusts portion sizes',
                            style: TextStyle(
                              color: colors.onSurface.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: () => _updateServings(-1),
                            color: _servings > 1
                                ? colors.onSurface
                                : colors.onSurface.withOpacity(0.4),
                          ),
                          Text(
                            '$_servings',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colors.onSurface,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => _updateServings(1),
                            color: _servings < 10
                                ? colors.onSurface
                                : colors.onSurface.withOpacity(0.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'From Inventory',
                subtitle: _activeItems.isEmpty ? null : 'Select items to use in today\'s recipe.',
                child: _activeItems.isEmpty
                    ? const _EmptyHint(
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
                              addedBy: item.ownerName,
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
                      const _EmptyHint(
                        icon: Icons.kitchen_outlined,
                        title: 'No extras added',
                        subtitle: 'Optional ingredients to help AI.',
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _extraIngredients.map((e) => Chip(
                          label: Text(
                            e,
                            style: TextStyle(fontSize: 13, color: colors.onSurface),
                          ),
                          backgroundColor: theme.cardColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: theme.dividerColor),
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
                  style: TextStyle(fontSize: 15, color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Any specific requests?',
                    hintStyle: TextStyle(color: colors.onSurface.withOpacity(0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: theme.cardColor,
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
              color: theme.cardColor,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: AppStyle.bg(context),
      appBar: AppBar(
        title: Text('Saved Recipes', style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface)),
        backgroundColor: AppStyle.bg(context),
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: Icon(Icons.delete_outline, color: colors.onSurface.withOpacity(0.6)),
            ),
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
                              color: AppStyle.cardColor(context),
                              shape: BoxShape.circle,
                              boxShadow: AppStyle.softShadow(context),
                            ),
                            child: Icon(
                              Icons.bookmark_border,
                              size: 48,
                              color: colors.onSurface.withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No recipes saved yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Generate recipes and tap the archive icon to save them here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.onSurface.withOpacity(0.6), height: 1.5),
                          ),
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
                                  initialServings: 2, // 默认值，因为归档不包含人数
                                ),
                              ),
                            ).then((_) => _reload());
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
  final int servings;
  final bool studentMode;

  const RecipeGeneratorSheet({
    super.key,
    required this.repo,
    required this.items,
    required this.extraIngredients,
    this.specialRequest,
    this.onInventoryUpdated,
    this.servings = 2,
    this.studentMode = false,
  });

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

      final body = <String, dynamic>{
        'ingredients': ingredients,
        'extraIngredients': widget.extraIngredients,
        'servings': widget.servings,
        'studentMode': widget.studentMode,
        'includeImages': true,
      };

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
      backgroundColor: AppStyle.bg(context),
      appBar: AppBar(backgroundColor: AppStyle.bg(context), title: const Text('AI Chef', style: TextStyle(fontWeight: FontWeight.w700)), centerTitle: false, elevation: 0),
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
        if (widget.items.isEmpty) const _EmptyHint(icon: Icons.info_outline, title: 'No Items', subtitle: 'Please select ingredients first.')
        else Wrap(spacing: 8, runSpacing: 8, children: widget.items.map((i) => Chip(label: Text(i.name), backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300))).toList()),
        
        if (widget.extraIngredients.isNotEmpty) ...[const SizedBox(height: 16), const Text('Extras', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: widget.extraIngredients.map((e) => Chip(label: Text(e), backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300))).toList())],
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text('Cooking for ${widget.servings} people', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w600)),
              if (widget.studentMode) ...[
                const SizedBox(width: 8),
                Container(width: 1, height: 16, color: Colors.blue.shade200),
                const SizedBox(width: 8),
                 Text('Student Mode ON', style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.w800, fontSize: 12)),
              ]
            ],
          ),
        ),

        if (widget.specialRequest != null && widget.specialRequest!.trim().isNotEmpty) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(children: [const Icon(Icons.star, color: Colors.orange, size: 18), const SizedBox(width: 8), Expanded(child: Text('Note: ${widget.specialRequest!}', style: TextStyle(color: Colors.brown.shade700)))],),)],
      ])),
      const Spacer(),
      _GradientPrimaryButton(onTap: _generate, icon: Icons.auto_awesome, title: 'Start Generating', subtitle: 'Create personalized recipes', enabled: true),
    ]);
  }

  Widget _buildLoading() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _ShimmerBlock(width: 180, height: 24),
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
        return _RecipeCard(
          recipe: recipe, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailPage(
            recipe: recipe, 
            repo: widget.repo, 
            usedItems: widget.items, 
            onInventoryUpdated: widget.onInventoryUpdated,
            initialServings: widget.servings, // 🟢 传递参数
          )))
        );
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
  final int initialServings; // 🟢

  const RecipeDetailPage({
    super.key,
    required this.recipe,
    required this.repo,
    required this.usedItems,
    this.onInventoryUpdated,
    this.initialServings = 2,
  });

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  static const String _backendBase = 'https://project-study-bsh.vercel.app';
  bool _hcActionLoading = false;
  bool _archiving = false;
  bool _isSaved = false;
  bool _isOvenReady = false;
  String? _ovenTempLabel;

  @override
  void initState() {
    super.initState();
    _checkSavedStatus();
  }

  Future<void> _checkSavedStatus() async {
    final saved = await RecipeArchiveStore.hasRecipe(widget.recipe.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<String?> _getSupabaseAccessTokenOrNull() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    return session?.accessToken;
  }

  Future<void> _toggleArchive() async {
    setState(() => _archiving = true);
    try {
      if (_isSaved) {
        await RecipeArchiveStore.remove(widget.recipe.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from archive')));
        if (mounted) setState(() => _isSaved = false);
      } else {
        await RecipeArchiveStore.add(widget.recipe);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to archive ✅')));
        if (mounted) setState(() => _isSaved = true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Operation failed: $e')));
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  Future<int?> _askTempC(BuildContext context, {int? initial}) async {
    final c = TextEditingController(text: initial != null ? initial.toString() : '');
    return showDialog<int?>(context: context, builder: (ctx) => AlertDialog(title: const Text('Oven temperature'), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'e.g. 200', suffixText: '°C')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')), TextButton(onPressed: () {final n = int.tryParse(c.text.trim()); Navigator.pop(ctx, n);}, child: const Text('OK'))]));
  }

  Future<String> _findOvenHaId(String token) async {
    final r = await http.get(Uri.parse('$_backendBase/api/hc?action=appliances'), headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
    if (r.statusCode != 200) throw Exception('Fetch appliances failed: ${r.statusCode} ${r.body}');
    final obj = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (obj['homeappliances'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    for (final a in list) { if ((a['type'] ?? '').toString().toLowerCase() == 'oven' || (a['name'] ?? '').toString().toLowerCase().contains('oven')) return a['haId'].toString(); }
    throw Exception('No oven appliance found');
  }

  Future<void> _preheatOven() async {
    if (_isOvenReady) {
      await _stopOven();
      return;
    }
    final ok = await requireLogin(context); if (!ok) return;
    final token = await _getSupabaseAccessTokenOrNull(); if (token == null) return;
    int? temp = widget.recipe.ovenTempC ?? widget.recipe.inferOvenTempFromText();
    if (temp == null) { temp = await _askTempC(context); if (temp == null) return; }
    setState(() => _hcActionLoading = true);
    try {
      final haId = await _findOvenHaId(token);
      final tempLabel = await _fetchOvenTemperature(token, haId);
      if (mounted) setState(() => _ovenTempLabel = tempLabel);
      final busy = await _isOvenBusy(token, haId);
      if (busy) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oven is busy. Stop it before preheating.')),
        );
        return;
      }
      final r = await http.post(
        Uri.parse('$_backendBase/api/hc?action=preheat'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'haId': haId,
          'temperatureC': temp,
          'programKey': 'Cooking.Oven.Program.HeatingMode.PreHeating'
        })
      );
      if (r.statusCode != 200) throw Exception('Failed: ${r.body}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Oven preheating to $temp°C ✅')));
      setState(() => _isOvenReady = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preheat failed: $e')));
    } finally {
      if (mounted) setState(() => _hcActionLoading = false);
    }
  }

  Future<void> _stopOven() async {
    final ok = await requireLogin(context); if (!ok) return;
    final token = await _getSupabaseAccessTokenOrNull(); if (token == null) return;
    setState(() => _hcActionLoading = true);
    try {
      final haId = await _findOvenHaId(token);
      final tempLabel = await _fetchOvenTemperature(token, haId);
      if (mounted) setState(() => _ovenTempLabel = tempLabel);
      final busy = await _isOvenBusy(token, haId);
      if (!busy) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oven is already idle.')),
        );
        setState(() => _isOvenReady = false);
        return;
      }
      final r = await http.post(
        Uri.parse('$_backendBase/api/hc?action=stopOven'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'haId': haId}),
      );
      if (r.statusCode != 200) throw Exception('Failed: ${r.body}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oven stopped.')));
      setState(() => _isOvenReady = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stop failed: $e')));
    } finally {
      if (mounted) setState(() => _hcActionLoading = false);
    }
  }

  Future<bool> _isOvenBusy(String token, String haId) async {
    final r = await http.get(
      Uri.parse('$_backendBase/api/hc?action=ovenStatus&haId=$haId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (r.statusCode != 200) return false;
    final obj = jsonDecode(r.body) as Map<String, dynamic>;
    final raw = obj['raw'] as Map<String, dynamic>? ?? {};
    final data = raw['data'] as Map<String, dynamic>? ?? raw;
    final activeKey = data['key'];
    return activeKey != null && activeKey.toString().isNotEmpty;
  }

  Future<String?> _fetchOvenTemperature(String token, String haId) async {
    final r = await http.get(
      Uri.parse('$_backendBase/api/hc?action=ovenStatusList&haId=$haId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (r.statusCode != 200) return null;
    final obj = jsonDecode(r.body) as Map<String, dynamic>;
    final raw = obj['raw'] as Map<String, dynamic>? ?? {};
    final data = raw['data'] as Map<String, dynamic>? ?? raw;
    final statusList = (data['status'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    Map<String, dynamic>? pick;
    for (final s in statusList) {
      final key = (s['key'] ?? '').toString();
      if (key.contains('CurrentTemperature') || key.contains('SetpointTemperature')) {
        pick = s;
        break;
      }
    }
    if (pick == null) return null;
    final value = pick['value'];
    final unit = pick['unit']?.toString() ?? '';
    if (value == null) return null;
    return '$value${unit.isNotEmpty ? ' $unit' : ''}';
  }

  IconData _toolIcon(String label) {
    if (label.toLowerCase().contains('oven')) return Icons.local_fire_department_rounded;
    return Icons.handyman_outlined;
  }

  // 🟢 核心优化：多步确认流程 (消耗确认 -> 剩菜确认 -> 执行)
  Future<void> _handleFinishCooking() async {
    // 1. 确认消耗量 (Smart Usage Review)
    // 返回 map: { itemId: usedQuantity }
    final usageMap = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IngredientUsageSheet(items: widget.usedItems),
    );

    if (usageMap == null) return; // 用户取消

    // 2. 确认剩菜 (Meal Prep)
    // 即使消耗量很少，也可能做了很多份，所以总是询问
    if (!mounted) return;
    final prepResult = await showModalBottomSheet<_MealPrepResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MealPrepDialog(totalServings: widget.initialServings),
    );

    if (prepResult == null) return; // 用户取消

    // 3. 执行逻辑 (Inventory Updates)
    
    // A. 扣减原材料
    for (final item in widget.usedItems) {
      final usedQty = usageMap[item.id] ?? 0.0;
      
      // 如果用户标记为“未使用” (0)，则跳过
      if (usedQty <= 0.01) continue;

      // 记录影响 (Impact)
      await widget.repo.recordImpactForAction(item, 'eat', overrideQty: usedQty);

      // 计算剩余
      final remaining = item.quantity - usedQty;

      if (remaining <= 0.01) {
        // 吃光了 -> 标记为 Consumed
        await widget.repo.updateStatus(item.id, FoodStatus.consumed);
      } else {
        // 没吃光 -> 更新数量
        final updatedItem = item.copyWith(quantity: remaining);
        await widget.repo.updateItem(updatedItem);
      }
    }

    // B. 处理剩菜入库
    if (prepResult.savedServings > 0) {
      final now = DateTime.now();
      // 冰箱+3天，冷冻+30天
      final daysToAdd = prepResult.location == StorageLocation.freezer ? 30 : 3;
      
      final leftoverItem = FoodItem(
        id: const Uuid().v4(),
        name: 'Leftover: ${widget.recipe.title}',
        category: 'cooked_meal',
        quantity: prepResult.savedServings.toDouble(),
        unit: 'servings',
        location: prepResult.location,
        purchasedDate: now,
        predictedExpiry: now.add(Duration(days: daysToAdd)),
        status: FoodStatus.good,
        ownerName: 'Me',
        source: 'meal_prep',
      );

      await widget.repo.addItem(leftoverItem);
    }

    // 4. 反馈与退出
    widget.onInventoryUpdated?.call();
    if (!mounted) return;
    
    final msg = prepResult.savedServings > 0
        ? 'Inventory updated & leftovers saved! 🍱'
        : 'Inventory updated! 😋';
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final ovenColor = _isOvenReady ? Colors.green : Colors.deepOrange;
    final ovenBgColor = _isOvenReady ? Colors.green.shade50 : Colors.orange.shade50;
    final ovenBorderColor = _isOvenReady ? Colors.green.shade100 : Colors.orange.shade100;

    return Scaffold(
      backgroundColor: AppStyle.bg(context),
      appBar: AppBar(
        title: const Text('Recipe Details', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppStyle.bg(context),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _archiving ? null : _toggleArchive,
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? AppStyle.primary : Colors.black87),
          )
        ]
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
        Hero(
          tag: 'recipe_img_${recipe.id}',
          child: _RecipeImage(
            imageUrl: recipe.imageUrl,
            height: 180,
            width: double.infinity,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 20),
        Text(recipe.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 8),
        Text('Yields ${widget.initialServings} servings', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [_InfoPill(icon: Icons.schedule, text: recipe.timeLabel, bg: Colors.grey.shade200, fg: Colors.black87), _InfoPill(icon: _toolIcon(recipe.appliancesLabel), text: recipe.appliancesLabel, bg: Colors.grey.shade200, fg: Colors.black87)]),
        const SizedBox(height: 24),
        if (recipe.description != null) ...[Text(recipe.description!, style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 15)), const SizedBox(height: 24)],

        if (recipe.usesOven) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ovenBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ovenBorderColor)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.smart_toy_outlined, color: ovenColor),
                  const SizedBox(width: 8),
                  Text('Smart Kitchen', style: TextStyle(fontWeight: FontWeight.bold, color: ovenColor))
                ]),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: _isOvenReady ? Icons.check_circle_rounded : Icons.local_fire_department_rounded,
                  iconColor: _isOvenReady ? Colors.green : AppStyle.primary,
                  title: _isOvenReady ? 'Oven is Ready' : 'Preheat Oven',
                  subtitle: _ovenTempLabel != null
                      ? 'Temp: $_ovenTempLabel'
                      : (_isOvenReady ? 'Tap to stop' : 'Tap to start'),
                  loading: _hcActionLoading,
                  onTap: _hcActionLoading ? null : _preheatOven,
                  bgColor: Colors.white
                )
              ]
            )
          )
        ],

        const SizedBox(height: 24),
        _SectionCard(title: 'Ingredients', child: Column(children: recipe.ingredients.map((ing) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: AppStyle.primary)), const SizedBox(width: 12), Expanded(child: Text(ing, style: const TextStyle(fontSize: 15, height: 1.4)))]))).toList())),
        const SizedBox(height: 24),

        const Padding(
          padding: EdgeInsets.only(bottom: 12, left: 4),
          child: Text('Instructions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recipe.steps.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 16),
          itemBuilder: (ctx, i) {
            final stepText = recipe.steps[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppStyle.softShadow(context),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppStyle.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'STEP ${i + 1}',
                          style: const TextStyle(
                            color: AppStyle.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stepText,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 56,
            child: widget.usedItems.isNotEmpty
              ? FilledButton.icon(
                  onPressed: _handleFinishCooking, // 🟢 调用新的逻辑
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('I Cooked This'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                )
              : null,
          ),
        ),
      ),
    );
  }
}

// 🟢 新增：消耗量确认 Sheet
class _IngredientUsageSheet extends StatefulWidget {
  final List<FoodItem> items;
  const _IngredientUsageSheet({required this.items});

  @override
  State<_IngredientUsageSheet> createState() => _IngredientUsageSheetState();
}

class _IngredientUsageSheetState extends State<_IngredientUsageSheet> {
  late Map<String, double> _usageMap;

  @override
  void initState() {
    super.initState();
    // 默认认为全用了 (Low operation cost)
    _usageMap = {
      for (var item in widget.items) item.id: item.quantity
    };
  }

  void _updateUsage(String id, double maxQty, double fraction) {
    setState(() {
      _usageMap[id] = (maxQty * fraction);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Review Ingredients Usage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Adjust if you didn\'t use everything (e.g. Oil, Spices).', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.items.length,
              separatorBuilder: (ctx, i) => const Divider(height: 24),
              itemBuilder: (ctx, i) {
                final item = widget.items[i];
                final usedQty = _usageMap[item.id]!;
                final isFull = (usedQty - item.quantity).abs() < 0.01;
                final isZero = usedQty <= 0.01;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        Text(
                          isFull ? 'All' : '-${usedQty.toStringAsFixed(1)} ${item.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isZero ? Colors.grey : (isFull ? Colors.red : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick chips for high accuracy with low clicks
                    Row(
                      children: [
                        _UsageChip(label: 'None', selected: isZero, onTap: () => setState(() => _usageMap[item.id] = 0)),
                        const SizedBox(width: 8),
                        _UsageChip(label: '¼', selected: false, onTap: () => _updateUsage(item.id, item.quantity, 0.25)),
                        const SizedBox(width: 8),
                        _UsageChip(label: '½', selected: false, onTap: () => _updateUsage(item.id, item.quantity, 0.5)),
                        const SizedBox(width: 8),
                        _UsageChip(label: 'All', selected: isFull, onTap: () => setState(() => _usageMap[item.id] = item.quantity)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          SafeArea(
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context, _usageMap);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: AppStyle.primary,
              ),
              child: const Text('Confirm Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _UsageChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppStyle.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700, 
            fontWeight: FontWeight.w600,
            fontSize: 12
          )
        ),
      ),
    );
  }
}

// 🟢 新增：备餐结果类
class _MealPrepResult {
  final int savedServings;
  final StorageLocation location;
  _MealPrepResult(this.savedServings, this.location);
}

// 🟢 新增：备餐选择对话框
class _MealPrepDialog extends StatefulWidget {
  final int totalServings;
  const _MealPrepDialog({required this.totalServings});

  @override
  State<_MealPrepDialog> createState() => _MealPrepDialogState();
}

class _MealPrepDialogState extends State<_MealPrepDialog> {
  int _savedServings = 0;
  StorageLocation _location = StorageLocation.fridge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Did you finish it all?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Or did you meal prep for later?', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          
          // Servings Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Leftovers to save:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              Container(
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _savedServings > 0 ? () => setState(() => _savedServings--) : null,
                    ),
                    Text('$_savedServings', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _savedServings < widget.totalServings ? () => setState(() => _savedServings++) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (_savedServings > 0) ...[
            const SizedBox(height: 24),
            const Text('Where will you store it?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StorageOption(
                    label: 'Fridge',
                    sub: '+3 Days',
                    icon: Icons.kitchen_rounded,
                    selected: _location == StorageLocation.fridge,
                    onTap: () => setState(() => _location = StorageLocation.fridge),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StorageOption(
                    label: 'Freezer',
                    sub: '+1 Month',
                    icon: Icons.ac_unit_rounded,
                    selected: _location == StorageLocation.freezer,
                    onTap: () => setState(() => _location = StorageLocation.freezer),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, _MealPrepResult(_savedServings, _location));
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: _savedServings > 0 ? AppStyle.primary : Colors.green.shade600,
            ),
            child: Text(
              _savedServings > 0 ? 'Save Leftovers' : 'Ate Everything!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageOption extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StorageOption({required this.label, required this.sub, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppStyle.primary.withOpacity(0.1) : Colors.white,
          border: Border.all(color: selected ? AppStyle.primary : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppStyle.primary : Colors.grey),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? AppStyle.primary : Colors.black87)),
            Text(sub, style: TextStyle(fontSize: 12, color: selected ? AppStyle.primary : Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ================== Helper Widgets & Models ==================

class _RecipeImage extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final double width;
  final BorderRadius borderRadius;

  const _RecipeImage({
    required this.imageUrl,
    required this.height,
    required this.width,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    final iconSize = height * 0.4;
    Widget content;

    if (url.isEmpty) {
      content = _placeholder(iconSize);
    } else if (url.startsWith('data:image')) {
      final b64 = _extractBase64(url);
      if (b64 == null) {
        content = _placeholder(iconSize);
      } else {
        try {
          final bytes = base64Decode(b64);
          content = Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: width,
            height: height,
          );
        } catch (_) {
          content = _placeholder(iconSize);
        }
      }
    } else {
      content = Image.network(
        url,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _placeholder(iconSize),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: width,
        child: content,
      ),
    );
  }

  String? _extractBase64(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma == -1) return null;
    return dataUrl.substring(comma + 1);
  }

  Widget _placeholder(double iconSize) {
    return Container(
      color: const Color(0xFFF0F5FF),
      alignment: Alignment.center,
      child: Icon(
        Icons.fastfood_rounded,
        size: iconSize,
        color: AppStyle.primary.withOpacity(0.3),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppStyle.softShadow(context),
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
                child: _RecipeImage(
                  imageUrl: recipe.imageUrl,
                  height: 50,
                  width: 50,
                  borderRadius: BorderRadius.circular(16),
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
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: colors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${recipe.timeLabel} • ${recipe.appliancesLabel}',
                      style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved on ${_fmt(addedAt)}',
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withOpacity(0.45)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, size: 20, color: colors.onSurface.withOpacity(0.5)),
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
        decoration: BoxDecoration(color: AppStyle.cardColor(context), borderRadius: BorderRadius.circular(20), boxShadow: AppStyle.softShadow(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Hero(
            tag: 'recipe_img_${recipe.id}',
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _RecipeImage(
                      imageUrl: recipe.imageUrl,
                      height: 100,
                      width: double.infinity,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  ),
                  if (recipe.expiringCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco, color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              'Uses ${recipe.expiringCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
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
class _ShimmerRecipeCardState extends State<_ShimmerRecipeCard> with SingleTickerProviderStateMixin { late AnimationController _controller; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _controller, builder: (context, child) { final color = Color.lerp(Colors.grey[200], Colors.grey[100], _controller.value); return Container(decoration: BoxDecoration(color: AppStyle.cardColor(context), borderRadius: BorderRadius.circular(20), boxShadow: AppStyle.softShadow(context)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 100, width: double.infinity, decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), color: color)), Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 6), Container(width: 100, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 12), Row(children: [Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Container(width: 60, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))]),],),),],),); },); } }
class _ShimmerArchiveCard extends StatefulWidget { const _ShimmerArchiveCard(); @override State<_ShimmerArchiveCard> createState() => _ShimmerArchiveCardState(); }
class _ShimmerArchiveCardState extends State<_ShimmerArchiveCard> with SingleTickerProviderStateMixin { late AnimationController _controller; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _controller, builder: (context, child) { final color = Color.lerp(Colors.grey[200], Colors.grey[100], _controller.value); return Container(decoration: BoxDecoration(color: AppStyle.cardColor(context), borderRadius: BorderRadius.circular(20), boxShadow: AppStyle.softShadow(context)), padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16))), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 8), Container(width: 120, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))]))])); },); } }
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(children: [
      Expanded(child: SizedBox(height: 48, child: TextField(
        controller: controller,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: colors.onSurface.withOpacity(0.5), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppStyle.primary)),
          filled: true,
          fillColor: theme.cardColor,
        ),
      ))),
      const SizedBox(width: 8),
      SizedBox(height: 48, width: 48, child: FilledButton(style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: AppStyle.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: onAdd, child: const Icon(Icons.add_rounded))),
    ]);
  }
}

class _ToggleRow extends StatelessWidget { final bool value; final String title; final String subtitle; final ValueChanged<bool> onChanged; const _ToggleRow({required this.value, required this.title, required this.subtitle, required this.onChanged}); @override Widget build(BuildContext context) { final colors = Theme.of(context).colorScheme; return InkWell(onTap: () => onChanged(!value), borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: value ? AppStyle.primary.withOpacity(0.05) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: value ? AppStyle.primary.withOpacity(0.2) : Colors.transparent)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: value ? AppStyle.primary : colors.onSurface)), Text(subtitle, style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6)))])), Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppStyle.primary)]))); } }
class _EmptyHint extends StatelessWidget { final IconData icon; final String title; final String subtitle; const _EmptyHint({required this.icon, required this.title, required this.subtitle}); @override Widget build(BuildContext context) { final theme = Theme.of(context); final colors = theme.colorScheme; return Container(padding: const EdgeInsets.all(20), alignment: Alignment.center, decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor, width: 1, style: BorderStyle.solid)), child: Column(children: [Icon(icon, color: colors.onSurface.withOpacity(0.35), size: 32), const SizedBox(height: 8), Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: 13))])); } }
class _GradientPrimaryButton extends StatelessWidget { final VoidCallback onTap; final IconData icon; final String title; final String subtitle; final bool enabled; const _GradientPrimaryButton({required this.onTap, required this.icon, required this.title, required this.subtitle, required this.enabled}); @override Widget build(BuildContext context) { return AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: enabled ? 1 : 0.6, child: Material(color: Colors.transparent, child: InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(16), child: Container(height: 60, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF005F87), Color(0xFF0079AD)]), borderRadius: BorderRadius.circular(16), boxShadow: [if (enabled) const BoxShadow(color: Color(0x40005F87), blurRadius: 12, offset: Offset(0, 4))]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 22), const SizedBox(width: 12), Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)), Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500))])]))))); } }
class _EntryTile extends StatelessWidget { final IconData icon; final String title; final String subtitle; final VoidCallback onTap; const _EntryTile({required this.icon, required this.title, required this.subtitle, required this.onTap}); @override Widget build(BuildContext context) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppStyle.cardRadius), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF0F5FF), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppStyle.primary)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600]))])), Icon(Icons.chevron_right_rounded, color: Colors.grey[400])]))); } }
class _SectionCard extends StatelessWidget { final String title; final String? subtitle; final Widget child; const _SectionCard({required this.title, this.subtitle, required this.child}); @override Widget build(BuildContext context) { final colors = Theme.of(context).colorScheme; return Container(decoration: BoxDecoration(color: AppStyle.cardColor(context), borderRadius: BorderRadius.circular(AppStyle.cardRadius), boxShadow: AppStyle.softShadow(context)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: colors.onSurface)), if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.6), height: 1.3))]])), const SizedBox(height: 12), Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child)])); } }
class _HeroCard extends StatelessWidget { final int selectedCount; final int preselectedCount; const _HeroCard({required this.selectedCount, required this.preselectedCount}); @override Widget build(BuildContext context) { return Container(height: 150, decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF005F87), Color(0xFF0082B8)]), boxShadow: const [BoxShadow(color: Color(0x33005F87), blurRadius: 20, offset: Offset(0, 10))]), child: Stack(children: [Positioned(right: -20, top: -20, child: Icon(Icons.restaurant_menu, size: 140, color: Colors.white.withOpacity(0.1))), Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text('$selectedCount', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800, height: 1.0)), const SizedBox(width: 8), const Text('items selected', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))]), const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.info_outline, size: 14, color: Colors.white), const SizedBox(width: 6), Text(preselectedCount > 0 ? '$preselectedCount items expiring soon' : 'Pick items to cook', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))]))]))])); } }
enum _Urgency { high, medium, low, neutral }
class _InventoryPickTile extends StatelessWidget { final String name; final String qtyText; final String expiryText; final _Urgency urgency; final bool selected; final VoidCallback onTap; final String? addedBy; const _InventoryPickTile({required this.name, required this.qtyText, required this.expiryText, required this.urgency, required this.selected, required this.onTap, this.addedBy}); Color _badgeColor() { switch (urgency) { case _Urgency.high: return Colors.red; case _Urgency.medium: return Colors.orange; case _Urgency.low: return Colors.green; case _Urgency.neutral: return Colors.grey; } } @override Widget build(BuildContext context) { final theme = Theme.of(context); final colors = theme.colorScheme; return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: selected ? AppStyle.primary.withOpacity(0.04) : theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? AppStyle.primary : theme.dividerColor, width: selected ? 1.5 : 1)), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: _badgeColor(), shape: BoxShape.circle)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: selected ? AppStyle.primary : colors.onSurface)), const SizedBox(height: 2), Text('$qtyText • $expiryText', style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6)))])), Container(width: 24, height: 24, decoration: BoxDecoration(color: selected ? AppStyle.primary : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: selected ? AppStyle.primary : colors.onSurface.withOpacity(0.3), width: 1.5)), child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null)]))); } }
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;
  final Color bgColor;
  final Color? iconColor;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
    this.bgColor = const Color(0xFFF5F7FA),
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final resolvedBg = isDark && bgColor == const Color(0xFFF5F7FA) ? theme.cardColor : bgColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: resolvedBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (iconColor ?? AppStyle.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? AppStyle.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              onTap == null && !loading
                  ? Icon(Icons.check, color: Colors.green.shade300)
                  : Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
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
    final appliancesRaw = m['appliances'] ?? m['tools'];
    List<String> appliances = (appliancesRaw is List)
        ? appliancesRaw.map((x) => x.toString()).toList()
        : const <String>[];
    if (appliances.isEmpty && m['toolPill'] is String) {
      final pill = (m['toolPill'] as String).trim();
      if (pill.isNotEmpty) appliances = [pill];
    }
    int? ovenTempC;
    final v = m['ovenTempC'];
    if (v is int) {
      ovenTempC = v;
    } else if (v is num) ovenTempC = v.round(); else if (v != null) ovenTempC = int.tryParse(v.toString());

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
    final text = ('$title\n${steps.join('\n')}').toLowerCase();
    return text.contains('oven') || text.contains('preheat') || text.contains('bake');
  }

  int? inferOvenTempFromText() {
    if (ovenTempC != null) return ovenTempC;
    final text = ('$title\n${steps.join('\n')}').toLowerCase();
    final reg = RegExp(r'(\d{2,3})\s*(°\s*c|°c|c\b|degrees?\s*c)');
    final m = reg.firstMatch(text);
    if (m != null) {
      final v = int.tryParse(m.group(1) ?? '');
      if (v != null && v >= 50 && v <= 300) return v;
    }
    return null;
  }

  String get appliancesLabel {
    final normalized = _normalizedTools(appliances);
    if (normalized.isNotEmpty) {
      if (normalized.length == 1) return normalized.first;
      return '${normalized.first} +${normalized.length - 1}';
    }
    final inferred = _inferToolsFromText();
    if (inferred.isNotEmpty) {
      if (inferred.length == 1) return inferred.first;
      return '${inferred.first} +${inferred.length - 1}';
    }
    return 'Basic tools';
  }

  List<String> _normalizedTools(List<String> tools) {
    final seen = <String>{};
    final out = <String>[];
    for (final t in tools) {
      final label = _formatToolName(t);
      if (label.isEmpty || seen.contains(label)) continue;
      seen.add(label);
      out.add(label);
    }
    return out;
  }

  String _formatToolName(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    final k = v.toLowerCase();
    if (k.contains('oven')) return 'Oven';
    if (k.contains('microwave')) return 'Microwave';
    if (k.contains('airfryer') || k.contains('air fryer')) return 'Air fryer';
    if (k.contains('ricecooker') || k.contains('rice cooker')) return 'Rice cooker';
    if (k.contains('blender')) return 'Blender';
    if (k.contains('pan') || k.contains('skillet')) return 'Pan';
    if (k.contains('pot')) return 'Pot';
    if (k.contains('knife')) return 'Knife';
    if (k.contains('stove') || k.contains('stovetop')) return 'Stovetop';
    return v;
  }

  List<String> _inferToolsFromText() {
    final text = ('$title\n${steps.join('\n')}').toLowerCase();
    final tools = <String>[];
    if (text.contains('oven') || text.contains('preheat') || text.contains('bake')) {
      tools.add('Oven');
    }
    if (text.contains('microwave')) {
      tools.add('Microwave');
    }
    if (text.contains('air fryer') || text.contains('airfryer')) {
      tools.add('Air fryer');
    }
    if (text.contains('rice cooker') || text.contains('ricecooker')) {
      tools.add('Rice cooker');
    }
    if (text.contains('blender')) {
      tools.add('Blender');
    }
    if (text.contains('pan') || text.contains('skillet') || text.contains('fry')) {
      tools.add('Pan');
    }
    if (text.contains('pot') || text.contains('boil') || text.contains('simmer')) {
      tools.add('Pot');
    }
    return tools;
  }
}
