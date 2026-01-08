// lib/models/food_item.dart

// 1. 保留这三个核心 Enum，因为它们只属于 FoodItem
enum StorageLocation { fridge, freezer, pantry }
enum FoodStatus { good, consumed, discarded }

// ⚠️ 注意：ImpactType 如果在 Repository 里也定义了，这里就不要定义。
// 如果您的 Repository 报错说找不到 ImpactType，请把下面这行取消注释：
// enum ImpactType { eaten, fedToPet, trashed } 

class FoodItem {
  final String id;
  final String name;
  final StorageLocation location;
  final double quantity;
  final String unit;
  final double? minQuantity;

  final DateTime purchasedDate;
  final DateTime? openDate;
  final DateTime? bestBeforeDate;
  final DateTime? predictedExpiry;

  final FoodStatus status;
  final String? category;
  final String? source;
  
  // 🟢 谁买的/谁添加的
  final String? ownerName;
  // 🟢 私有物品标记
  final bool isPrivate; 

  FoodItem({
    required this.id,
    required this.name,
    required this.location,
    required this.quantity,
    required this.unit,
    this.minQuantity,
    required this.purchasedDate,
    this.openDate,
    this.bestBeforeDate,
    this.predictedExpiry,
    this.status = FoodStatus.good,
    this.category,
    this.source,
    this.ownerName,
    this.isPrivate = false,
  });

  // ================== Helper Getters ==================

  int get daysToExpiry {
    if (predictedExpiry == null) return 999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      predictedExpiry!.year,
      predictedExpiry!.month,
      predictedExpiry!.day,
    );
    return expiry.difference(today).inDays;
  }

  bool get isLowStock {
    if (minQuantity == null) return false;
    return status == FoodStatus.good && quantity <= minQuantity!;
  }

  // ================== CopyWith ==================

  FoodItem copyWith({
    String? id,
    String? name,
    StorageLocation? location,
    double? quantity,
    String? unit,
    double? minQuantity,
    DateTime? purchasedDate,
    DateTime? openDate,
    DateTime? bestBeforeDate,
    DateTime? predictedExpiry,
    FoodStatus? status,
    String? category,
    String? source,
    String? ownerName,
    bool? isPrivate,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      minQuantity: minQuantity ?? this.minQuantity,
      purchasedDate: purchasedDate ?? this.purchasedDate,
      openDate: openDate ?? this.openDate,
      bestBeforeDate: bestBeforeDate ?? this.bestBeforeDate,
      predictedExpiry: predictedExpiry ?? this.predictedExpiry,
      status: status ?? this.status,
      category: category ?? this.category,
      source: source ?? this.source,
      ownerName: ownerName ?? this.ownerName,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  // ================== JSON Serialization ==================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location.name,
      'quantity': quantity,
      'unit': unit,
      'min_quantity': minQuantity,
      'purchased_date': purchasedDate.toIso8601String(),
      'open_date': openDate?.toIso8601String(),
      'best_before_date': bestBeforeDate?.toIso8601String(),
      'predicted_expiry': predictedExpiry?.toIso8601String(),
      'status': status.name,
      'category': category,
      'source': source,
      'owner_name': ownerName,
      'is_private': isPrivate,
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    StorageLocation parseLocation(dynamic value) {
      if (value == null) return StorageLocation.fridge;
      final s = value.toString().toLowerCase(); 
      if (s.contains('freezer')) return StorageLocation.freezer;
      if (s.contains('pantry')) return StorageLocation.pantry;
      return StorageLocation.fridge;
    }

    FoodStatus parseStatus(dynamic value) {
      if (value == null) return FoodStatus.good;
      final s = value.toString().toLowerCase();
      if (s == 'consumed') return FoodStatus.consumed;
      if (s == 'discarded') return FoodStatus.discarded;
      return FoodStatus.good;
    }

    double parseDouble(dynamic value, {double defaultValue = 0.0}) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    double? parseDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    String? extractName(Map<String, dynamic> data) {
      if (data['user_profiles'] != null && data['user_profiles'] is Map) {
        return data['user_profiles']['display_name'];
      }
      if (data['owner_name'] != null) {
        return data['owner_name'];
      }
      return null;
    }

    return FoodItem(
      id: json['id'].toString(),
      name: json['name'] ?? 'Unknown',
      location: parseLocation(json['location']),
      quantity: parseDouble(json['quantity'], defaultValue: 1.0),
      unit: json['unit'] ?? 'pcs',
      minQuantity: parseDoubleNullable(json['min_quantity']),
      purchasedDate: parseDate(json['purchased_date']) ?? DateTime.now(),
      openDate: parseDate(json['open_date']),
      bestBeforeDate: parseDate(json['best_before_date']),
      predictedExpiry: parseDate(json['predicted_expiry']),
      status: parseStatus(json['status']),
      category: json['category'],
      source: json['source'],
      ownerName: extractName(json),
      isPrivate: json['is_private'] ?? false,
    );
  }
}