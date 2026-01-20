class MealPlan {
  final String id;
  final String? familyId;
  final String userId;
  final DateTime planDate;
  final String slot;
  final String mealName;
  final String? recipeName;
  final Set<String> itemIds;
  final List<String> missingItems;
  final DateTime updatedAt;

  MealPlan({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.planDate,
    required this.slot,
    required this.mealName,
    required this.recipeName,
    required this.itemIds,
    required this.missingItems,
    required this.updatedAt,
  });

  Map<String, dynamic> toDbJson() {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'plan_date': _dateOnly(planDate),
      'slot': slot,
      'meal_name': mealName,
      'recipe_name': recipeName,
      'item_ids': itemIds.toList(),
      'missing_items': missingItems,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'plan_date': _dateOnly(planDate),
      'slot': slot,
      'meal_name': mealName,
      'recipe_name': recipeName,
      'item_ids': itemIds.toList(),
      'missing_items': missingItems,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: json['id'].toString(),
      familyId: json['family_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      planDate: DateTime.tryParse(json['plan_date']?.toString() ?? '') ?? DateTime.now(),
      slot: json['slot']?.toString() ?? 'dinner',
      mealName: json['meal_name']?.toString() ?? '',
      recipeName: json['recipe_name']?.toString(),
      itemIds: (json['item_ids'] as List? ?? []).map((e) => e.toString()).toSet(),
      missingItems: (json['missing_items'] as List? ?? []).map((e) => e.toString()).toList(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

String _dateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
