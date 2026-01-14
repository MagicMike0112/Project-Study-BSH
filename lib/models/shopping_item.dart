import 'package:flutter/foundation.dart';

class ShoppingItem {
  final String id;
  final String name;
  final String category;
  bool isChecked;
  final String? ownerName;
  final String? userId;

  ShoppingItem({
    required this.id,
    required this.name,
    this.category = 'general',
    this.isChecked = false,
    this.ownerName,
    this.userId,
  });

  Map<String, dynamic> toDbJson(String familyId, String currentUserId) {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId ?? currentUserId,
      'name': name,
      'category': category,
      'is_checked': isChecked,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalJson(String familyId, String currentUserId) {
    var map = toDbJson(familyId, currentUserId);
    map['owner_name'] = ownerName;
    return map;
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    String? extractName(Map<String, dynamic> data) {
      if (data['user_profiles'] != null && data['user_profiles'] is Map) {
        return data['user_profiles']['display_name'];
      }
      if (data['owner_name'] != null) {
        return data['owner_name'];
      }
      return null;
    }

    return ShoppingItem(
      id: json['id'].toString(),
      name: json['name'] ?? 'Unknown',
      category: json['category'] ?? 'general',
      isChecked: json['is_checked'] ?? false,
      ownerName: extractName(json),
      userId: json['user_id']?.toString(),
    );
  }
}