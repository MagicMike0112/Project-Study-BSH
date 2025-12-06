// lib/repositories/inventory_repository.dart
import 'package:uuid/uuid.dart';
import '../models/food_item.dart';

/// 后面可以用 AI 替换这里的逻辑，只保留接口不动
class ExpiryService {
  DateTime predictExpiry(
    String? category,
    StorageLocation location,
    DateTime purchased, {
    DateTime? openDate,
    DateTime? bestBefore,
  }) {
    // ======= 极简规则版：先保证能跑 =======
    int days = 7;

    // 按存储位置粗分
    if (location == StorageLocation.freezer) {
      days = 90;
    } else if (location == StorageLocation.pantry) {
      days = 14;
    } else if (location == StorageLocation.fridge) {
      days = 5;
    }

    // 如果有包装保质期，优先用包装日期做上限
    if (bestBefore != null) {
      final ruleDate = purchased.add(Duration(days: days));
      if (ruleDate.isAfter(bestBefore)) return bestBefore;
      return ruleDate;
    }

    // 如果有开封日期，可以略微缩短一点时间（示意）
    if (openDate != null) {
      days = (days * 0.7).round(); // 开封后保质期缩短到 70%
      return openDate.add(Duration(days: days));
    }

    return purchased.add(Duration(days: days));
  }
}

/// 用户行为对 Impact 的记录：做成菜 / 喂给宠物
enum ImpactType { cooked, fedToPet }

class ImpactEvent {
  final DateTime date;
  final ImpactType type;
  final double quantity; // 使用的数量（与 FoodItem 的 unit 对应）
  final String unit;
  final double moneySaved; // €，用于图表
  final double co2Saved; // kg CO₂

  ImpactEvent({
    required this.date,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.moneySaved,
    required this.co2Saved,
  });
}

class InventoryRepository {
  final List<FoodItem> _items = [];

  final ExpiryService _expiryService = ExpiryService();

  /// 所有 impact 事件（做菜 / 喂宠物）
  final List<ImpactEvent> _impactEvents = [];

  /// 是否已经给过“喂宠物安全提示”
  bool hasShownPetWarning = false;

  InventoryRepository() {
    // 模拟数据
    _items.add(
      FoodItem(
        id: const Uuid().v4(),
        name: 'Greek Yogurt',
        location: StorageLocation.fridge,
        quantity: 2,
        unit: 'cups',
        purchasedDate: DateTime.now().subtract(const Duration(days: 2)),
        predictedExpiry: DateTime.now().add(const Duration(days: 1)),
        status: FoodStatus.good,
      ),
    );
    _items.add(
      FoodItem(
        id: const Uuid().v4(),
        name: 'Carrots',
        location: StorageLocation.fridge,
        quantity: 500,
        unit: 'g',
        purchasedDate: DateTime.now(),
        predictedExpiry: DateTime.now().add(const Duration(days: 4)),
        status: FoodStatus.good,
      ),
    );
  }

  // ================== Items ==================

  List<FoodItem> getActiveItems() =>
      _items.where((i) => i.status == FoodStatus.good).toList();

  List<FoodItem> getExpiringItems(int withinDays) {
    return getActiveItems()
        .where((i) => i.daysToExpiry <= withinDays)
        .toList();
  }

  int getSavedCount() =>
      _items.where((i) => i.status == FoodStatus.consumed).length;

  Future<void> addItem(FoodItem item) async => _items.add(item);

  Future<void> updateItem(FoodItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) _items[index] = item;
  }

  Future<void> updateStatus(String id, FoodStatus status) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(status: status);
    }
  }

  /// 供表单使用：根据输入信息计算预测保质期
  DateTime predictExpiryForItem(FoodItem base) {
    return _expiryService.predictExpiry(
      base.category,
      base.location,
      base.purchasedDate,
      openDate: base.openDate,
      bestBefore: base.bestBeforeDate,
    );
  }

  // ================== Impact 相关 ==================

  /// 只读暴露给 Impact 页面
  List<ImpactEvent> get impactEvents => List.unmodifiable(_impactEvents);

  /// 用户用快要过期食材做菜
  void logCooked(FoodItem item, {double? quantity}) {
    final usedQty = quantity ?? item.quantity;
    final money = _estimateMoneySaved(item, usedQty);
    final co2 = _estimateCo2Saved(item, usedQty);

    _impactEvents.add(
      ImpactEvent(
        date: DateTime.now(),
        type: ImpactType.cooked,
        quantity: usedQty,
        unit: item.unit,
        moneySaved: money,
        co2Saved: co2,
      ),
    );
  }

  /// 用户把食材喂给宠物（Impact 页面里宠物卡片要用到）
  void logFedToPet(FoodItem item, {double? quantity}) {
    final usedQty = quantity ?? item.quantity;
    final money = _estimateMoneySaved(item, usedQty);
    final co2 = _estimateCo2Saved(item, usedQty);

    _impactEvents.add(
      ImpactEvent(
        date: DateTime.now(),
        type: ImpactType.fedToPet,
        quantity: usedQty,
        unit: item.unit,
        moneySaved: money,
        co2Saved: co2,
      ),
    );
  }

  // --- 简单估算逻辑：后期可以换成真实 LCA/价格数据 ---
  double _estimateMoneySaved(FoodItem item, double quantity) {
    if (item.unit.toLowerCase() == 'g') {
      const per100g = 0.5;
      return (quantity / 100.0) * per100g;
    }
    if (item.unit.toLowerCase() == 'kg') {
      const perKg = 5.0;
      return quantity * perKg;
    }
    // 其他单位先按 1 €/unit
    return quantity * 1.0;
  }

  double _estimateCo2Saved(FoodItem item, double quantity) {
    if (item.unit.toLowerCase() == 'g') {
      const per100g = 0.3;
      return (quantity / 100.0) * per100g;
    }
    if (item.unit.toLowerCase() == 'kg') {
      const perKg = 3.0;
      return quantity * perKg;
    }
    // 其他单位先按 0.5 kg / unit
    return quantity * 0.5;
  }

  double totalMoneySavedSince(DateTime from) {
    return _impactEvents
        .where((e) => e.date.isAfter(from))
        .fold(0.0, (sum, e) => sum + e.moneySaved);
  }

  double totalCo2SavedSince(DateTime from) {
    return _impactEvents
        .where((e) => e.date.isAfter(from))
        .fold(0.0, (sum, e) => sum + e.co2Saved);
  }

  double totalFedToPetQuantitySince(DateTime from) {
    return _impactEvents
        .where(
          (e) =>
              e.type == ImpactType.fedToPet && e.date.isAfter(from),
        )
        .fold(0.0, (sum, e) => sum + e.quantity);
  }
}
