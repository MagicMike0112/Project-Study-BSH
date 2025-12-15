// lib/screens/archive_recipe_detail_page.dart
import 'package:flutter/material.dart';

import '../services/archive_service.dart';

class ArchiveRecipeDetailPage extends StatelessWidget {
  final ArchivedRecipe recipe;

  const ArchiveRecipeDetailPage({super.key, required this.recipe});

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
          if (recipe.description != null && recipe.description!.trim().isNotEmpty) ...[
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
