// lib/repositories/inventory_repository.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
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

  // ---------- JSON 序列化 ----------

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'type': type.name, // cooked / fedToPet
      'quantity': quantity,
      'unit': unit,
      'moneySaved': moneySaved,
      'co2Saved': co2Saved,
    };
  }

  factory ImpactEvent.fromJson(Map<String, dynamic> json) {
    ImpactType parseType(String? value) {
      switch (value) {
        case 'fedToPet':
          return ImpactType.fedToPet;
        case 'cooked':
        default:
          return ImpactType.cooked;
      }
    }

    return ImpactEvent(
      date: DateTime.parse(json['date'] as String),
      type: parseType(json['type'] as String?),
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      moneySaved: (json['moneySaved'] as num).toDouble(),
      co2Saved: (json['co2Saved'] as num).toDouble(),
    );
  }
}

class InventoryRepository {
  // ---------- 本地存储 key ----------
  static const _itemsKey = 'inv_items_v1';
  static const _impactKey = 'inv_impact_v1';
  static const _metaKey = 'inv_meta_v1';

  final List<FoodItem> _items;
  final List<ImpactEvent> _impactEvents;
  final ExpiryService _expiryService = ExpiryService();

  /// 是否已经给过“喂宠物安全提示”
  bool hasShownPetWarning = false;

  /// streak 相关
  int _streakDays = 0;
  DateTime? _lastConsumedDate;

  // 私有构造
  InventoryRepository._(this._items, this._impactEvents);

  /// 工厂：带“落盘 & 读取”的创建方式
  static Future<InventoryRepository> create() async {
    final prefs = await SharedPreferences.getInstance();

    // ---------- 1. 读取 items ----------
    final itemsJson = prefs.getString(_itemsKey);
    final List<FoodItem> items = [];

    if (itemsJson != null) {
      try {
        final decoded = jsonDecode(itemsJson) as List<dynamic>;
        for (final e in decoded) {
          items.add(FoodItem.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {
        // 解析失败就当没数据
      }
    }


    // ---------- 2. 读取 impact events ----------
    final impactJson = prefs.getString(_impactKey);
    final List<ImpactEvent> impactEvents = [];
    if (impactJson != null) {
      try {
        final decoded = jsonDecode(impactJson) as List<dynamic>;
        for (final e in decoded) {
          impactEvents.add(ImpactEvent.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    // ---------- 3. 读取 meta（streak / lastConsumed / pet warning 等） ----------
    final metaJson = prefs.getString(_metaKey);
    final repo = InventoryRepository._(items, impactEvents);

    if (metaJson != null) {
      try {
        final m = jsonDecode(metaJson) as Map<String, dynamic>;
        repo._streakDays = (m['streakDays'] as num?)?.toInt() ?? 0;
        final lastIso = m['lastConsumed'] as String?;
        if (lastIso != null) {
          repo._lastConsumedDate = DateTime.tryParse(lastIso);
        }
        repo.hasShownPetWarning = m['petWarningShown'] == true;
      } catch (_) {}
    }

    return repo;
  }

  // ---------- 内部：保存到本地 ----------

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _saveItems() async {
    final prefs = await _prefs();
    final list = _items.map((e) => e.toJson()).toList();
    await prefs.setString(_itemsKey, jsonEncode(list));
  }

  Future<void> _saveImpact() async {
    final prefs = await _prefs();
    final list = _impactEvents.map((e) => e.toJson()).toList();
    await prefs.setString(_impactKey, jsonEncode(list));
  }

  Future<void> _saveMeta() async {
    final prefs = await _prefs();
    final meta = <String, dynamic>{
      'streakDays': _streakDays,
      'lastConsumed': _lastConsumedDate?.toIso8601String(),
      'petWarningShown': hasShownPetWarning,
    };
    await prefs.setString(_metaKey, jsonEncode(meta));
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

  Future<void> addItem(FoodItem item) async {
    _items.add(item);
    await _saveItems();
  }

  Future<void> updateItem(FoodItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
      await _saveItems();
    }
  }

  /// 删除一个 item（给 Inventory 左滑、Edit 页面用）
  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _saveItems();
  }

  Future<void> updateStatus(String id, FoodStatus status) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = _items[index];
      _items[index] = item.copyWith(status: status);
      await _saveItems();

      // 只在 “成功吃掉/利用” 的时候更新 streak
      if (status == FoodStatus.consumed) {
        _updateStreakOnConsumed();
        await _saveMeta();
      }
    }
  }

  /// 部分/全部使用一个食材，并记录 impact
  /// [action]: 'eat' / 'pet'
  /// [usedQty]: 用户这次用了多少（单位 = item.unit）
  Future<void> useItemWithImpact(
    FoodItem item,
    String action,
    double usedQty,
  ) async {
    if (usedQty <= 0) return;

    // 1. clamp 在 [0, item.quantity]
    final double clamped = usedQty.clamp(0, item.quantity).toDouble();

    // 2. 记录 impact
    if (action == 'eat') {
      logCooked(item, quantity: clamped);
    } else if (action == 'pet') {
      logFedToPet(item, quantity: clamped);
    }
    await _saveImpact();

    // 3. 更新库存数量
    final remaining = item.quantity - clamped;

    if (remaining <= 0.0001) {
      // 等于或几乎等于 0：整条算吃完
      await updateStatus(item.id, FoodStatus.consumed);
    } else {
      // 只用掉了一部分：这条 item 继续存在，只是 quantity 变少
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _items[index] = item.copyWith(quantity: remaining);
        await _saveItems();
      }
    }
  }

  /// 提供一个安全的方式来标记“宠物提示已显示”，顺便落盘
  Future<void> markPetWarningShown() async {
    if (!hasShownPetWarning) {
      hasShownPetWarning = true;
      await _saveMeta();
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

  /// （保留一个旧接口，其他地方暂时不用）
  Future<void> recordImpactForAction(FoodItem item, String action) async {
    if (action == 'eat') {
      logCooked(item);
    } else if (action == 'pet') {
      logFedToPet(item);
    }
    await _saveImpact();
  }

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
          (e) => e.type == ImpactType.fedToPet && e.date.isAfter(from),
        )
        .fold(0.0, (sum, e) => sum + e.quantity);
  }

  // ================== streak 相关 ==================

  void _updateStreakOnConsumed() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastConsumedDate == null) {
      _streakDays = 1;
    } else {
      final last = DateTime(
        _lastConsumedDate!.year,
        _lastConsumedDate!.month,
        _lastConsumedDate!.day,
      );
      final diff = today.difference(last).inDays;

      if (diff == 1) {
        // 连续一天
        _streakDays += 1;
      } else if (diff > 1) {
        // 断档，重新开始
        _streakDays = 1;
      } // diff == 0 同一天多次吃东西，不重复加
    }

    _lastConsumedDate = today;
  }

  int getCurrentStreakDays() => _streakDays;
}
