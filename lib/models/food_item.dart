// lib/models/food_item.dart

enum StorageLocation { fridge, freezer, pantry }
enum FoodStatus { good, consumed, discarded }

class FoodItem {
  final String id;
  final String name;
  final StorageLocation location;
  final double quantity;
  final String unit;

  /// 必填：购买日期
  final DateTime purchasedDate;

  /// 可选：开封日期
  final DateTime? openDate;

  /// 可选：包装上的 Best-before / Use-by
  final DateTime? bestBeforeDate;

  /// 预测的“真正过期日”（可以来自规则或 AI）
  final DateTime? predictedExpiry;

  final FoodStatus status;
  final String? category;
  final String? source;

  FoodItem({
    required this.id,
    required this.name,
    required this.location,
    required this.quantity,
    required this.unit,
    required this.purchasedDate,
    this.openDate,
    this.bestBeforeDate,
    this.predictedExpiry,
    this.status = FoodStatus.good,
    this.category,
    this.source,
  });

  /// 距离 predictedExpiry 还有几天；如果没有，就给一个大数方便排序
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

  FoodItem copyWith({
    String? id,
    String? name,
    StorageLocation? location,
    double? quantity,
    String? unit,
    DateTime? purchasedDate,
    DateTime? openDate,
    DateTime? bestBeforeDate,
    DateTime? predictedExpiry,
    FoodStatus? status,
    String? category,
    String? source,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      purchasedDate: purchasedDate ?? this.purchasedDate,
      openDate: openDate ?? this.openDate,
      bestBeforeDate: bestBeforeDate ?? this.bestBeforeDate,
      predictedExpiry: predictedExpiry ?? this.predictedExpiry,
      status: status ?? this.status,
      category: category ?? this.category,
      source: source ?? this.source,
    );
  }
}
