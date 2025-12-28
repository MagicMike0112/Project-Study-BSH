// lib/models/food_item.dart

// 移除：import 'package:supabase_flutter/supabase_flutter.dart'; 
// Model 类不需要依赖 Supabase 库，保持纯净，避免离线时报错

enum StorageLocation { fridge, freezer, pantry }
enum FoodStatus { good, consumed, discarded }

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
  
  // 🟢 新增字段：谁买的/谁添加的
  final String? ownerName;

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
    this.ownerName, // 🟢 新增参数
  });

  // ================== Helper Getters ==================

  int get daysToExpiry {
    if (predictedExpiry == null) return 999;
    final now = DateTime.now();
    // 只比较日期部分，忽略时分秒
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
    String? ownerName, // 🟢 新增参数
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
      ownerName: ownerName ?? this.ownerName, // 🟢 赋值
    );
  }

  // ================== JSON Serialization ==================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // 'user_id': ... 移除由 Repo 统一处理
      'name': name,
      'location': location.name, // 存字符串: "fridge"
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
      'owner_name': ownerName, // 🟢 序列化到本地缓存
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    // 内部 Helper：安全解析枚举
    StorageLocation parseLocation(dynamic value) {
      if (value == null) return StorageLocation.fridge;
      // 兼容可能的大小写问题
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

    // 内部 Helper：安全解析数字 (处理 int/double/String 混合的情况)
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

    // 🟢 智能解析名字逻辑
    String? extractName(Map<String, dynamic> data) {
      // 1. 如果是从 Supabase 关联查询回来的 (user_profiles -> display_name)
      if (data['user_profiles'] != null && data['user_profiles'] is Map) {
        return data['user_profiles']['display_name'];
      }
      // 2. 如果是从本地缓存读取的扁平结构
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
      ownerName: extractName(json), // 🟢 赋值
    );
  }
}