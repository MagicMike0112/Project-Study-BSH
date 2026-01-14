// lib/models/impact_event.dart

// 🟢 修改点：将 trashed 改为 trash，以便与 Repository 代码匹配
enum ImpactType { 
  eaten, 
  fedToPet, 
  trash 
}

class ImpactEvent {
  final String id;
  final DateTime date;
  final ImpactType type;
  final double quantity;
  final String unit;
  final double moneySaved;
  final double co2Saved;
  
  final String? itemName;
  final String? itemCategory;

  ImpactEvent({
    required this.id,
    required this.date,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.moneySaved,
    required this.co2Saved,
    this.itemName,
    this.itemCategory,
  });

  Map<String, dynamic> toJson(String familyId, String userId) {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'created_at': date.toIso8601String(),
      'type': type.name, // 存入数据库时会是 'trash'
      'quantity': quantity,
      'unit': unit,
      'money_saved': moneySaved,
      'co2_saved': co2Saved,
      'item_name': itemName,
      'item_category': itemCategory,
    };
  }

  factory ImpactEvent.fromJson(Map<String, dynamic> json) {
    return ImpactEvent(
      id: json['id'].toString(),
      date: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      // 🟢 健壮性处理：这里做一点兼容，防止数据库里存的是旧的字符串
      type: ImpactType.values.firstWhere(
        (e) {
            final dbType = json['type'] as String;
            // 兼容 'trash' 和 'trashed'，如果数据库里已经存了 'trashed' 也能读出来
            if (e.name == 'trash' && (dbType == 'trash' || dbType == 'trashed')) {
                return true;
            }
            return e.name == dbType;
        },
        orElse: () => ImpactType.eaten,
      ),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? '',
      moneySaved: (json['money_saved'] as num?)?.toDouble() ?? 0.0,
      co2Saved: (json['co2_saved'] as num?)?.toDouble() ?? 0.0,
      itemName: json['item_name'],
      itemCategory: json['item_category'],
    );
  }
}