import '../utils/app_time.dart';

class GuestShoppingList {
  final String id;
  final String title;
  final String shareToken;
  final DateTime expiresAt;
  final String? ownerId;
  final bool allowGuests;
  final List<String> participants;
  final String? guestDisplayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  GuestShoppingList({
    required this.id,
    required this.title,
    required this.shareToken,
    required this.expiresAt,
    required this.ownerId,
    required this.allowGuests,
    required this.participants,
    required this.guestDisplayName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GuestShoppingList.fromJson(Map<String, dynamic> json) {
    return GuestShoppingList(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? 'Guest List',
      shareToken: json['share_token']?.toString() ?? '',
      expiresAt: AppTime.parseServerTimestamp(json['expires_at']) ?? DateTime.now().add(const Duration(days: 1)),
      ownerId: json['owner_id']?.toString(),
      allowGuests: json['allow_guests'] == true,
      participants: (json['participants'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      guestDisplayName: json['guest_display_name']?.toString(),
      createdAt: AppTime.parseServerTimestamp(json['created_at']) ?? DateTime.now(),
      updatedAt: AppTime.parseServerTimestamp(json['updated_at']) ?? DateTime.now(),
    );
  }
}

class GuestShoppingItem {
  final String id;
  final String listId;
  final String name;
  final double? quantity;
  final String? unit;
  final bool isChecked;
  final String? note;
  final String? updatedBy;
  final String? editorName;
  final String? editorEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  GuestShoppingItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isChecked,
    required this.note,
    required this.updatedBy,
    required this.editorName,
    required this.editorEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toDbJson(String listId, String? userId) {
    return {
      'id': id,
      'list_id': listId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'is_checked': isChecked,
      'note': note,
      'editor_name': editorName,
      'updated_by': userId,
      'updated_at': AppTime.toUtcIso(DateTime.now()),
    };
  }

  factory GuestShoppingItem.fromJson(Map<String, dynamic> json) {
    String? displayName;
    String? email;
    final explicitEditorName = json['editor_name']?.toString();
    if (json['user_profiles'] is Map) {
      final profile = json['user_profiles'] as Map;
      displayName = profile['display_name']?.toString();
      email = profile['email']?.toString();
    }
    return GuestShoppingItem(
      id: json['id'].toString(),
      listId: json['list_id'].toString(),
      name: json['name']?.toString() ?? 'Unknown',
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit']?.toString(),
      isChecked: json['is_checked'] == true,
      note: json['note']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      editorName: (explicitEditorName != null && explicitEditorName.trim().isNotEmpty)
          ? explicitEditorName
          : displayName,
      editorEmail: email,
      createdAt: AppTime.parseServerTimestamp(json['created_at']) ?? DateTime.now(),
      updatedAt: AppTime.parseServerTimestamp(json['updated_at']) ?? DateTime.now(),
    );
  }
}


