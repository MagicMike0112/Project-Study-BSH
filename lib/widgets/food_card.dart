// lib/widgets/food_card.dart
import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../l10n/app_localizations.dart';

class FoodCard extends StatelessWidget {
  final FoodItem item;
  final Function(String action) onAction; // NOTE: legacy comment cleaned.
  final VoidCallback? onTap;

  // NOTE: legacy comment cleaned.
  // NOTE: legacy comment cleaned.
  final Widget? leading;

  const FoodCard({
    super.key,
    required this.item,
    required this.onAction,
    this.leading,
    this.onTap,
  });

  String _locationLabel(StorageLocation loc, AppLocalizations? l10n) {
    switch (loc) {
      case StorageLocation.fridge:
        return l10n?.foodLocationFridge ?? 'Fridge';
      case StorageLocation.freezer:
        return l10n?.foodLocationFreezer ?? 'Freezer';
      case StorageLocation.pantry:
        return l10n?.foodLocationPantry ?? 'Pantry';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = item.daysToExpiry <= 1;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final daysLabel = item.daysToExpiry < 0
        ? (l10n?.foodExpiredDaysAgo(-item.daysToExpiry) ?? 'Expired ${-item.daysToExpiry}d ago')
        : (l10n?.foodDaysLeft(item.daysToExpiry) ?? '${item.daysToExpiry} days left');

    final bgColor = isCritical
        ? scheme.errorContainer.withValues(alpha: 0.15)
        : scheme.primaryContainer.withValues(alpha: 0.15);
    final iconColor = isCritical ? scheme.error : scheme.primary;

    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: onTap,
        // NOTE: legacy comment cleaned.
        leading: leading ??
            CircleAvatar(
              backgroundColor: bgColor,
              child: Icon(Icons.timer, color: iconColor),
            ),
        title: Text(
          item.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: scheme.onSurface,
          ),
        ),
        subtitle: Text(
          '$daysLabel - ${_locationLabel(item.location, l10n)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: PopupMenuButton(
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          menuPadding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'eat',
              child: Row(
                children: [
                  Icon(Icons.restaurant, size: 18),
                  SizedBox(width: 8),
                  Text(l10n?.foodActionCookEat ?? 'Cook / Eat'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pet',
              child: Row(
                children: [
                  Icon(Icons.pets, size: 18),
                  SizedBox(width: 8),
                  Text(l10n?.foodActionFeedPets ?? 'Feed Pets'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'trash',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18),
                  SizedBox(width: 8),
                  Text(l10n?.foodActionDiscard ?? 'Discard'),
                ],
              ),
            ),
          ],
          onSelected: (val) {
            onAction(val);
            if (val == 'pet') {
              // NOTE: legacy comment cleaned.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n?.foodPetsHappy ?? 'Little Shi & Little Yuan are happy!'),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}




