part of '../select_ingredients_page.dart';

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
    final l10n = AppLocalizations.of(context);
    setState(() => _state = 1);
    try {
      final ingredients = widget.items
          .map((i) => '${i.name} (${i.quantity} ${i.unit})')
          .toList();
      final uri = Uri.parse('$_backendBase/api/recipe');

      final body = <String, dynamic>{
        'ingredients': ingredients,
        'extraIngredients': widget.extraIngredients,
        'servings': widget.servings,
        'studentMode': widget.studentMode,
        'includeImages': true,
        'locale': AppLocale.fromContext(context),
      };

      if (widget.specialRequest != null &&
          widget.specialRequest!.trim().isNotEmpty)
        body['specialRequest'] = widget.specialRequest!.trim();

      final locale = AppLocale.fromContext(context);
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept-Language': locale,
          'X-App-Locale': locale,
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode != 200)
        throw Exception('Server error: ${resp.statusCode} - ${resp.body}');

      final root = jsonDecode(resp.body);
      List<dynamic> rawList =
          (root is Map<String, dynamic> && root['recipes'] is List)
              ? root['recipes']
              : (root is List ? root : []);

      _recipes = rawList.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return RecipeSuggestion.fromJson(m);
      }).toList();

      if (!mounted) return;
      setState(() => _state = 2);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.recipeGeneratorFailed(e.toString()) ??
                'AI recipe failed: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppStyle.bg(context),
      appBar: AppBar(
          backgroundColor: AppStyle.bg(context),
          title: Text(
            l10n?.todayAiChefTitle ?? 'AI Chef',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          centerTitle: false,
          elevation: 0),
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
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(
          title: l10n?.recipeGeneratorReviewSelectionTitle ?? 'Review Selection',
          subtitle: l10n?.recipeGeneratorReviewSelectionDesc ??
              'AI will prioritize these expiring items.',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.items.isEmpty)
              _EmptyHint(
                  icon: Icons.info_outline,
                  title: l10n?.recipeGeneratorNoItemsTitle ?? 'No Items',
                  subtitle: l10n?.recipeGeneratorNoItemsDesc ??
                      'Please select ingredients first.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.items
                    .map(
                      (i) => Chip(
                        avatar: _IngredientAvatar(
                          name: i.name,
                          category: i.category,
                        ),
                        label: Text(i.name),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    )
                    .toList(),
              ),
            if (widget.extraIngredients.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n?.recipeGeneratorExtrasTitle ?? 'Extras',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.extraIngredients
                    .map(
                      (e) => Chip(
                        avatar: _IngredientAvatar(name: e),
                        label: Text(e),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    )
                    .toList(),
              )
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100)),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined,
                      color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n?.recipeGeneratorCookingFor(
                            widget.servings.toString(),
                          ) ??
                          'Cooking for ${widget.servings}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (widget.studentMode) ...[
                    const SizedBox(width: 8),
                    Container(
                        width: 1, height: 16, color: Colors.blue.shade200),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(
                        l10n?.recipeGeneratorStudentModeOn ??
                            'Student Mode ON',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.indigo.shade800,
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            if (widget.specialRequest != null &&
                widget.specialRequest!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            (l10n?.recipeGeneratorNote(
                                      widget.specialRequest!,
                                    )) ??
                                'Note: ${widget.specialRequest!}',
                            style: TextStyle(color: Colors.brown.shade700)))
                  ],
                ),
              )
            ],
          ])),
      const Spacer(),
      _GradientPrimaryButton(
          onTap: _generate,
          icon: Icons.auto_awesome,
          title: l10n?.recipeGeneratorStartTitle ?? 'Start Generating',
          subtitle: l10n?.recipeGeneratorStartSubtitle ??
              'Create personalized recipes',
          enabled: true),
    ]);
  }

  Widget _buildLoading() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _ShimmerBlock(width: 180, height: 24),
      const SizedBox(height: 16),
      Expanded(
          child: GridView.builder(
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75),
              itemBuilder: (context, index) => const _ShimmerRecipeCard())),
    ]);
  }

  Widget _buildResult() {
    final l10n = AppLocalizations.of(context);
    if (_recipes.isEmpty)
      return Center(
        child: Text(
          l10n?.recipeGeneratorNoRecipes ?? 'No recipes generated.',
        ),
      );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(l10n?.recipeGeneratorSuggestionsTitle ?? 'Suggestions for you',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20))),
      Expanded(
          child: GridView.builder(
              itemCount: _recipes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75),
              itemBuilder: (context, index) {
                final recipe = _recipes[index];
                return _RecipeCard(
                    recipe: recipe,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RecipeDetailPage(
                                  recipe: recipe,
                                  repo: widget.repo,
                                  usedItems: widget.items,
                                  onInventoryUpdated: widget.onInventoryUpdated,
                                ))));
              })),
    ]);
  }
}

// ================== Detail Page ==================

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
        decoration: BoxDecoration(
            color: AppStyle.cardColor(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppStyle.softShadow(context)),
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
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  ),
                  if (recipe.expiringCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              'Uses ${recipe.expiringCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.2)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.schedule,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(recipe.timeLabel,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600))
                    ]),
                  ])),
        ]),
      ),
    );
  }
}
