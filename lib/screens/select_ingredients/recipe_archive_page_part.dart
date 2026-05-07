part of '../select_ingredients_page.dart';

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
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n?.recipeArchiveClearTitle ?? 'Clear archive?'),
          content: Text(
            l10n?.recipeArchiveClearDesc ??
                'This will remove all archived recipes.',
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n?.recipeArchiveClearAll ?? 'Clear All'),
            ),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppStyle.bg(context),
      appBar: AppBar(
        title: Text(
          l10n?.recipeArchiveSavedTitle ?? 'Saved Recipes',
          style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        backgroundColor: AppStyle.bg(context),
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: Icon(Icons.delete_outline, color: colors.onSurface.withValues(alpha: 0.6)),
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
                              color: colors.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n?.recipeArchiveEmptyTitle ??
                                'No recipes saved yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n?.recipeArchiveEmptyDesc ??
                                'Generate recipes and tap the archive icon to save them here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6), height: 1.5),
                          ),
                          const SizedBox(height: 32),
                          FilledButton.tonal(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              l10n?.recipeArchiveGoBack ?? 'Go Back',
                            ),
                          ),
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
    final l10n = AppLocalizations.of(context);
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
                      '${recipe.timeLabel} | ${recipe.appliancesLabel}',
                      style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.recipeArchiveSavedOn(_fmt(addedAt)) ??
                          'Saved on ${_fmt(addedAt)}',
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, size: 20, color: colors.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerArchiveCard extends StatefulWidget {
  const _ShimmerArchiveCard();

  @override
  State<_ShimmerArchiveCard> createState() => _ShimmerArchiveCardState();
}

class _ShimmerArchiveCardState extends State<_ShimmerArchiveCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color = Color.lerp(Colors.grey[200], Colors.grey[100], _controller.value);
        return Container(
          decoration: BoxDecoration(
            color: AppStyle.cardColor(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppStyle.softShadow(context),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
