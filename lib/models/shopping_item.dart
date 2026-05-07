// lib/models/shopping_item.dart
import '../utils/app_time.dart';

class ShoppingItem {
  final String id;
  final String name;
  final String category;
  bool isChecked;
  final String? ownerName;
  final String? userId;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ShoppingItem({
    required this.id,
    required this.name,
    this.category = 'general',
    this.isChecked = false,
    this.ownerName,
    this.userId,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toDbJson(String familyId, String currentUserId) {
    final map = <String, dynamic>{
      'id': id,
      'family_id': familyId,
      'user_id': userId ?? currentUserId,
      'name': name,
      'category': category,
      'is_checked': isChecked,
      'updated_at': AppTime.toUtcIso(DateTime.now()),
      'note': note,
    };
    if (createdAt != null) {
      map['created_at'] = AppTime.toUtcIso(createdAt!);
    }
    return map;
  }

  Map<String, dynamic> toLocalJson(String familyId, String currentUserId) {
    final map = toDbJson(familyId, currentUserId);
    map['owner_name'] = ownerName;
    if (updatedAt != null) {
      map['updated_at'] = AppTime.toUtcIso(updatedAt!);
    }
    if (createdAt != null) {
      map['created_at'] = AppTime.toUtcIso(createdAt!);
    }
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
      note: json['note'],
      createdAt: AppTime.parseServerTimestamp(json['created_at']),
      updatedAt: AppTime.parseServerTimestamp(json['updated_at']),
    );
  }
}
