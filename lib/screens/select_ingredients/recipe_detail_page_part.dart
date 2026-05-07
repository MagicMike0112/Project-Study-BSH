part of '../select_ingredients_page.dart';

class RecipeDetailPage extends StatefulWidget {
  final RecipeSuggestion recipe;
  final InventoryRepository repo;
  final List<FoodItem> usedItems;
  final VoidCallback? onInventoryUpdated;
  final int initialServings;

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

class _IngredientAvatar extends StatelessWidget {
  final String name;
  final String? category;

  const _IngredientAvatar({required this.name, this.category});

  @override
  Widget build(BuildContext context) {
    final assetPath = foodIconAssetForName(name, category: category);
    if (assetPath.endsWith('/default.png')) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: Colors.grey.shade200,
        child: Text(
          name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey.shade100,
      child: Image.asset(
        assetPath,
        width: 18,
        height: 18,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Text(
            name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          );
        },
      ),
    );
  }
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
    final l10n = AppLocalizations.of(context);
    setState(() => _archiving = true);
    try {
      if (_isSaved) {
        await RecipeArchiveStore.remove(widget.recipe.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n?.recipeDetailRemovedFromArchive ?? 'Removed from archive')));
        if (mounted) setState(() => _isSaved = false);
      } else {
        await RecipeArchiveStore.add(widget.recipe);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n?.recipeDetailSavedToArchive ?? 'Saved to archive')));
        if (mounted) setState(() => _isSaved = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.recipeDetailOperationFailed(e.toString()) ??
                  'Operation failed: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
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
    final l10n = AppLocalizations.of(context);
    if (_isOvenReady) {
      await _stopOven();
      return;
    }
    final ok = await requireLogin(context); if (!ok) return;
    final token = await _getSupabaseAccessTokenOrNull(); if (token == null) return;
    final temp = widget.recipe.ovenTempC ?? widget.recipe.inferOvenTempFromText();
    if (temp == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.recipeDetailNoOvenTemp ?? 'No oven temperature found in this recipe.')),
      );
      return;
    }
    setState(() => _hcActionLoading = true);
    try {
      final haId = await _findOvenHaId(token);
      final tempLabel = await _fetchOvenTemperature(token, haId);
      if (mounted) setState(() => _ovenTempLabel = tempLabel);
      final busy = await _isOvenBusy(token, haId);
      if (busy) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.recipeDetailOvenBusy ?? 'Oven is busy. Stop it before preheating.')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.recipeDetailOvenPreheating(temp.toString()) ??
                'Oven preheating to $temp°C',
          ),
        ),
      );
      setState(() => _isOvenReady = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.recipeDetailPreheatFailed(e.toString()) ??
                'Preheat failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _hcActionLoading = false);
    }
  }

  Future<void> _stopOven() async {
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text(l10n?.recipeDetailOvenAlreadyIdle ?? 'Oven is already idle.')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n?.recipeDetailOvenStopped ?? 'Oven stopped.')));
      setState(() => _isOvenReady = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.recipeDetailStopFailed(e.toString()) ?? 'Stop failed: $e',
          ),
        ),
      );
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

  Future<void> _handleFinishCooking() async {
    // NOTE: legacy comment cleaned.
    // NOTE: legacy comment cleaned.
    final usageMap = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IngredientUsageSheet(items: widget.usedItems),
    );

    if (usageMap == null) return; // NOTE: legacy comment cleaned.

    // NOTE: legacy comment cleaned.
    // NOTE: legacy comment cleaned.
    if (!mounted) return;
    final prepResult = await showModalBottomSheet<_MealPrepResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MealPrepDialog(totalServings: widget.initialServings),
    );

    if (prepResult == null) return; // NOTE: legacy comment cleaned.

    // NOTE: legacy comment cleaned.
    
    for (final item in widget.usedItems) {
      final usedQty = usageMap[item.id] ?? 0.0;
      
      if (usedQty <= 0.01) continue;

      // NOTE: legacy comment cleaned.
      await widget.repo.recordImpactForAction(item, 'eat', overrideQty: usedQty);

      // NOTE: legacy comment cleaned.
      final remaining = item.quantity - usedQty;

      if (remaining <= 0.01) {
        await widget.repo.updateStatus(item.id, FoodStatus.consumed);
      } else {
        final updatedItem = item.copyWith(quantity: remaining);
        await widget.repo.updateItem(updatedItem);
      }
    }

    // NOTE: legacy comment cleaned.
    if (prepResult.savedServings > 0) {
      final now = DateTime.now();
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

    widget.onInventoryUpdated?.call();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    final msg = prepResult.savedServings > 0
        ? (l10n?.recipeDetailSavedLeftoversToInventory ?? 'Saved leftovers to inventory.')
        : (l10n?.recipeDetailInventoryUpdated ?? 'Inventory updated.');
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recipe = widget.recipe;
    final ovenColor = _isOvenReady ? Colors.green : Colors.deepOrange;
    final ovenBgColor = _isOvenReady ? Colors.green.shade50 : Colors.orange.shade50;
    final ovenBorderColor = _isOvenReady ? Colors.green.shade100 : Colors.orange.shade100;
    final ovenTargetTemp = recipe.usesOven ? (recipe.ovenTempC ?? recipe.inferOvenTempFromText()) : null;

    return Scaffold(
      backgroundColor: AppStyle.bg(context),
      appBar: AppBar(
        title: Text(l10n?.recipeDetailTitle ?? 'Recipe Details', style: const TextStyle(fontWeight: FontWeight.w700)),
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
        Text(
          l10n?.recipeDetailYields(widget.initialServings.toString()) ??
              'Yields ${widget.initialServings} servings',
          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
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
                  Text(l10n?.recipeDetailSmartKitchen ?? 'Smart Kitchen', style: TextStyle(fontWeight: FontWeight.bold, color: ovenColor))
                ]),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: _isOvenReady ? Icons.check_circle_rounded : Icons.local_fire_department_rounded,
                  iconColor: _isOvenReady ? Colors.green : AppStyle.primary,
                  title: _isOvenReady
                      ? (l10n?.recipeDetailOvenReady ?? 'Oven is Ready')
                      : (ovenTargetTemp == null
                          ? l10n?.recipeDetailPreheatOven ?? 'Preheat Oven'
                          : (l10n?.recipeDetailPreheatTo(
                                    ovenTargetTemp.toString(),
                                  ) ??
                                  'Preheat to $ovenTargetTemp°C')),
                  subtitle: _ovenTempLabel != null
                      ? (l10n?.recipeDetailTemp(_ovenTempLabel!) ??
                          'Temp: $_ovenTempLabel')
                      : (_isOvenReady ? l10n?.recipeDetailTapToStop ?? 'Tap to stop' : l10n?.recipeDetailTapToStart ?? 'Tap to start'),
                  loading: _hcActionLoading,
                  onTap: _hcActionLoading ? null : _preheatOven,
                  bgColor: Colors.white
                )
              ]
            )
          )
        ],

        const SizedBox(height: 24),
        _SectionCard(title: l10n?.recipeDetailIngredientsTitle ?? 'Ingredients', child: Column(children: recipe.ingredients.map((ing) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: AppStyle.primary)), const SizedBox(width: 12), Expanded(child: Text(ing, style: const TextStyle(fontSize: 15, height: 1.4)))]))).toList())),
        const SizedBox(height: 24),

        Padding(
          padding: EdgeInsets.only(bottom: 12, left: 4),
          child: Text(l10n?.recipeDetailInstructionsTitle ?? 'Instructions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
                          color: AppStyle.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n?.recipeDetailStep((i + 1).toString()) ??
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
            child: FilledButton.icon(
              onPressed: widget.usedItems.isNotEmpty ? _handleFinishCooking : null,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(l10n?.recipeDetailCookedThis ?? 'I Cooked This'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final l10n = AppLocalizations.of(context);
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
          Text(l10n?.recipeDetailReviewUsageTitle ?? 'Review Ingredients Usage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
                          isFull ? (l10n?.recipeDetailAllLabel ?? 'All') : '-${usedQty.toStringAsFixed(1)} ${item.unit}',
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
                        _UsageChip(label: l10n?.recipeDetailUsageNone ?? 'None', selected: isZero, onTap: () => setState(() => _usageMap[item.id] = 0)),
                        const SizedBox(width: 8),
                        _UsageChip(label: '1/4', selected: false, onTap: () => _updateUsage(item.id, item.quantity, 0.25)),
                        const SizedBox(width: 8),
                        _UsageChip(label: '1/2', selected: false, onTap: () => _updateUsage(item.id, item.quantity, 0.5)),
                        const SizedBox(width: 8),
                        _UsageChip(label: l10n?.recipeDetailUsageAll ?? 'All', selected: isFull, onTap: () => setState(() => _usageMap[item.id] = item.quantity)),
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
              child: Text(l10n?.recipeDetailConfirmUsage ?? 'Confirm Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    final theme = Theme.of(context);
    final bg = selected
        ? AppStyle.primary
        : (theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade100);
    final fg = selected
        ? Colors.white
        : (theme.brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade700);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppStyle.primary.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _MealPrepResult {
  final int savedServings;
  final StorageLocation location;
  _MealPrepResult(this.savedServings, this.location);
}

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
    final l10n = AppLocalizations.of(context);
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
          Text(l10n?.recipeDetailMealPrepTitle ?? 'Did you finish it all?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n?.recipeDetailMealPrepDesc ?? 'Or did you meal prep for later?', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          
          // Servings Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n?.recipeDetailLeftoversToSave ?? 'Leftovers to save:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
            Text(l10n?.recipeDetailWhereStoreLeftovers ?? 'Where will you store it?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StorageOption(
                    label: l10n?.foodLocationFridge ?? 'Fridge',
                    sub: '+3 Days',
                    icon: Icons.kitchen_rounded,
                    selected: _location == StorageLocation.fridge,
                    onTap: () => setState(() => _location = StorageLocation.fridge),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StorageOption(
                    label: l10n?.foodLocationFreezer ?? 'Freezer',
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
              _savedServings > 0 ? (l10n?.recipeDetailSaveLeftovers ?? 'Save Leftovers') : (l10n?.recipeDetailAteEverything ?? 'Ate Everything!'),
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
          color: selected ? AppStyle.primary.withValues(alpha: 0.1) : Colors.white,
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
        color: AppStyle.primary.withValues(alpha: 0.3),
      ),
    );
  }
}





