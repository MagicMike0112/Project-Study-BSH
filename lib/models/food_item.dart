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

  // ---------------- JSON 序列化 ----------------

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location.name, // fridge / freezer / pantry
      'quantity': quantity,
      'unit': unit,
      'purchasedDate': purchasedDate.toIso8601String(),
      'openDate': openDate?.toIso8601String(),
      'bestBeforeDate': bestBeforeDate?.toIso8601String(),
      'predictedExpiry': predictedExpiry?.toIso8601String(),
      'status': status.name, // good / consumed / discarded
      'category': category,
      'source': source,
    };
  }

  /// 容错 fromJson：老数据字段缺失/类型错了也尽量兜住，不让整个 app 崩
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    StorageLocation parseLocation(dynamic value) {
      final s = value?.toString();
      switch (s) {
        case 'freezer':
          return StorageLocation.freezer;
        case 'pantry':
          return StorageLocation.pantry;
        case 'fridge':
        default:
          return StorageLocation.fridge;
      }
    }

    FoodStatus parseStatus(dynamic value) {
      final s = value?.toString();
      switch (s) {
        case 'consumed':
          return FoodStatus.consumed;
        case 'discarded':
          return FoodStatus.discarded;
        case 'good':
        default:
          return FoodStatus.good;
      }
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isEmpty) return null;
      if (v is String) {
        return DateTime.tryParse(v);
      }
      if (v is int) {
        // 兼容毫秒时间戳的旧数据
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
      return null;
    }

    double parseQuantity(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
      return 1.0; // 默认 1
    }

    // 整体再包一层 try，实在解析不出来就给一个“安全兜底” item
    try {
      final rawId = json['id']?.toString();
      final rawName = json['name']?.toString();

      return FoodItem(
        id: (rawId == null || rawId.isEmpty)
            ? 'legacy-${DateTime.now().millisecondsSinceEpoch}'
            : rawId,
        name: (rawName == null || rawName.isEmpty)
            ? 'Unnamed item'
            : rawName,
        location: parseLocation(json['location']),
        quantity: parseQuantity(json['quantity']),
        unit: (json['unit']?.toString().isNotEmpty ?? false)
            ? json['unit'].toString()
            : 'pcs',
        purchasedDate: parseDate(json['purchasedDate']) ??
            DateTime.now(), // 没有就用 now，避免崩
        openDate: parseDate(json['openDate']),
        bestBeforeDate: parseDate(json['bestBeforeDate']),
        predictedExpiry: parseDate(json['predictedExpiry']),
        status: parseStatus(json['status']),
        category: json['category']?.toString(),
        source: json['source']?.toString(),
      );
    } catch (e) {
      // 万一上面哪一步直接炸了，这里做最后兜底
      // 只要不 throw，Flutter 就不会在启动阶段直接挂掉
      final fallbackName = json['name']?.toString() ?? 'Unknown item';
      return FoodItem(
        id: 'fallback-${DateTime.now().millisecondsSinceEpoch}',
        name: fallbackName,
        location: StorageLocation.fridge,
        quantity: 1.0,
        unit: 'pcs',
        purchasedDate: DateTime.now(),
        status: FoodStatus.good,
      );
    }
  }
}
