class ShoppingHistoryItem {
  final String id;
  final String name;
  final String? userId;
  final String? shoppingItemId;
  final String category;
  final DateTime date;

  ShoppingHistoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.date,
    this.userId,
    this.shoppingItemId,
  });

  Map<String, dynamic> toJson(String familyId, String userId) {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'shopping_item_id': shoppingItemId,
      'name': name,
      'category': category,
      'added_date': date.toIso8601String(),
    };
  }

  factory ShoppingHistoryItem.fromJson(Map<String, dynamic> json) {
    return ShoppingHistoryItem(
      id: json['id'].toString(),
      name: json['name'] ?? 'Unknown',
      category: json['category'] ?? 'general',
      date: DateTime.tryParse(json['added_date'].toString()) ?? DateTime.now(),
      userId: json['user_id']?.toString(),
      shoppingItemId: json['shopping_item_id']?.toString(),
    );
  }
}