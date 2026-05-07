import '../utils/app_time.dart';

enum StorageLocation { fridge, freezer, pantry }
enum FoodStatus { good, consumed, discarded }

class FoodItem {
  static const Object _sentinel = Object();

  final String id;
  final String name; // 产品具体名称，如 "Lays Classic"
  final String? genericName; // 新增：通用名称，如 "Potato Chips"
  final StorageLocation location;
  final double quantity;
  final String unit;
  final double? minQuantity;

  final DateTime purchasedDate;
  final DateTime? openDate;
  final DateTime? bestBeforeDate;
  final DateTime? predictedExpiry;
  final DateTime? updatedAt;

  final FoodStatus status;
  final String? category; // 大分类，如 "Snacks"
  final String? source;
  
  final String? ownerName;
  final String? note;
  final bool isPrivate; 

  FoodItem({
    required this.id,
    required this.name,
    this.genericName, // Initialize
    required this.location,
    required this.quantity,
    required this.unit,
    this.minQuantity,
    required this.purchasedDate,
    this.openDate,
    this.bestBeforeDate,
    this.predictedExpiry,
    this.updatedAt,
    this.status = FoodStatus.good,
    this.category,
    this.source,
    this.ownerName,
    this.note,
    this.isPrivate = false,
  });

  // ================== Helper Getters ==================

  // 获取用于显示的名字：如果有具体通用名，可以组合显示，或者只显示 name
  // 这里保留原逻辑，只显示 name，您可以在 UI 层决定怎么展示
  String get displayName => name; 

  // 获取用于 AI 预测的名字：优先使用通用名，因为 AI 对 "Potato Chips" 的过期理解比对 "Lays" 更准
  String get nameForAi => genericName != null && genericName!.isNotEmpty ? genericName! : name;

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
    Object? genericName = _sentinel, // Add to copyWith
    StorageLocation? location,
    double? quantity,
    String? unit,
    Object? minQuantity = _sentinel,
    DateTime? purchasedDate,
    Object? openDate = _sentinel,
    Object? bestBeforeDate = _sentinel,
    Object? predictedExpiry = _sentinel,
    Object? updatedAt = _sentinel,
    FoodStatus? status,
    Object? category = _sentinel,
    Object? source = _sentinel,
    Object? ownerName = _sentinel,
    Object? note = _sentinel,
    bool? isPrivate,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      genericName: identical(genericName, _sentinel)
          ? this.genericName
          : genericName as String?,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      minQuantity: identical(minQuantity, _sentinel)
          ? this.minQuantity
          : minQuantity as double?,
      purchasedDate: purchasedDate ?? this.purchasedDate,
      openDate: identical(openDate, _sentinel)
          ? this.openDate
          : openDate as DateTime?,
      bestBeforeDate: identical(bestBeforeDate, _sentinel)
          ? this.bestBeforeDate
          : bestBeforeDate as DateTime?,
      predictedExpiry: identical(predictedExpiry, _sentinel)
          ? this.predictedExpiry
          : predictedExpiry as DateTime?,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
      status: status ?? this.status,
      category: identical(category, _sentinel)
          ? this.category
          : category as String?,
      source: identical(source, _sentinel)
          ? this.source
          : source as String?,
      ownerName: identical(ownerName, _sentinel)
          ? this.ownerName
          : ownerName as String?,
      note: identical(note, _sentinel)
          ? this.note
          : note as String?,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  // ================== JSON Serialization ==================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'generic_name': genericName, // Serialize
      'location': location.name,
      'quantity': quantity,
      'unit': unit,
      'min_quantity': minQuantity,
      'purchased_date': purchasedDate.toIso8601String(),
      'open_date': openDate?.toIso8601String(),
      'best_before_date': bestBeforeDate?.toIso8601String(),
      'predicted_expiry': predictedExpiry?.toIso8601String(),
      'updated_at': updatedAt == null ? null : AppTime.toUtcIso(updatedAt!),
      'status': status.name,
      'category': category,
      'source': source,
      'owner_name': ownerName,
      'note': note,
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
      if (value is String) return AppTime.parseServerTimestamp(value);
      return null;
    }

    String? extractName(Map<String, dynamic> data) {
      if (data['user_profiles'] != null && data['user_profiles'] is Map) {
        final profile = data['user_profiles'] as Map;
        final displayName = profile['display_name'];
        if (displayName != null && displayName.toString().isNotEmpty) {
          return displayName;
        }
        final email = profile['email'];
        if (email != null && email.toString().isNotEmpty) {
          return email;
        }
      }
      if (data['owner_name'] != null) {
        return data['owner_name'];
      }
      return null;
    }

    return FoodItem(
      id: json['id'].toString(),
      name: json['name'] ?? 'Unknown',
      genericName: json['generic_name'], // Deserialize
      location: parseLocation(json['location']),
      quantity: parseDouble(json['quantity'], defaultValue: 1.0),
      unit: json['unit'] ?? 'pcs',
      minQuantity: parseDoubleNullable(json['min_quantity']),
      purchasedDate: parseDate(json['purchased_date']) ?? DateTime.now(),
      openDate: parseDate(json['open_date']),
      bestBeforeDate: parseDate(json['best_before_date']),
      predictedExpiry: parseDate(json['predicted_expiry']),
      updatedAt: parseDate(json['updated_at']), 
      status: parseStatus(json['status']),
      category: json['category'],
      source: json['source'],
      ownerName: extractName(json),
      note: json['note'],
      isPrivate: json['is_private'] ?? false,
    );
  }
}



