import '../utils/app_time.dart';

// NOTE: legacy comment cleaned.
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
  final String? userId;
  
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
    this.userId,
  });

  Map<String, dynamic> toJson(String familyId, String userId) {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'created_at': AppTime.toUtcIso(date),
      'type': type.name, // NOTE: legacy comment cleaned.
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
      date: AppTime.parseServerTimestamp(json['created_at']) ?? DateTime.now(),
      // NOTE: legacy comment cleaned.
      type: ImpactType.values.firstWhere(
        (e) {
            final dbType = json['type'] as String;
            // NOTE: legacy comment cleaned.
            if (e.name == 'trash' && (dbType == 'trash' || dbType == 'trashed')) {
                return true;
            }
            if (e.name == 'fedToPet' && (dbType == 'fedToPet' || dbType == 'fed_to_pet' || dbType == 'pet')) {
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
      userId: json['user_id']?.toString(),
    );
  }
}



