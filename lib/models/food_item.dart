// lib/models/food_item.dart

enum StorageLocation { fridge, freezer, pantry }
enum FoodStatus { good, consumed, discarded }

class FoodItem {
  final String id;
  final String name;
  final StorageLocation location;
  final double quantity;
  final String unit;

  /// 购买日期（UI 上可选填，这里依然保留字段，没填可以用 today 或 null，取决于你后面怎么用）
  final DateTime purchasedDate;

  /// 开封日期（可选）
  final DateTime? openDate;

  /// 包装上的保质期（可选）
  final DateTime? bestBeforeDate;

  /// 预测保质期（后面可由 AI/规则推断）
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

  /// 优先使用 predictedExpiry，其次用 bestBeforeDate
  int get daysToExpiry {
    final DateTime? base = predictedExpiry ?? bestBeforeDate;
    if (base == null) return 999;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(base.year, base.month, base.day);
    return expiry.difference(today).inDays;
  }

  /// 方便在 UI 中显示的“预测日期”（优先 AI 预测，其次包装日）
  DateTime? get effectiveExpiryDate => predictedExpiry ?? bestBeforeDate;

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
