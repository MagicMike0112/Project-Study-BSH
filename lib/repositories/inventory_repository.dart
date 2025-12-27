// lib/repositories/inventory_repository.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';

// ================== Models ==================

class ShoppingItem {
  final String id;
  final String name;
  final String category; // 'dairy', 'produce', 'meat', 'general', 'pet'
  bool isChecked;

  ShoppingItem({
    required this.id,
    required this.name,
    this.category = 'general',
    this.isChecked = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'isChecked': isChecked,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'],
      name: json['name'],
      category: json['category'] ?? 'general',
      isChecked: json['isChecked'] ?? false,
    );
  }
}

class ShoppingHistoryItem {
  final String name;
  final String category;
  final DateTime date;

  ShoppingHistoryItem({
    required this.name,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'date': date.toIso8601String(),
  };

  factory ShoppingHistoryItem.fromJson(Map<String, dynamic> json) {
    return ShoppingHistoryItem(
      name: json['name'],
      category: json['category'],
      date: DateTime.parse(json['date']),
    );
  }
}

/// Expiry Service (Stub for now)
class ExpiryService {
  DateTime predictExpiry(
    String? category,
    StorageLocation location,
    DateTime purchased, {
    DateTime? openDate,
    DateTime? bestBefore,
  }) {
    int days = 7;
    if (location == StorageLocation.freezer) {
      days = 90;
    } else if (location == StorageLocation.pantry) {
      days = 14;
    } else if (location == StorageLocation.fridge) {
      days = 5;
    }

    if (bestBefore != null) {
      final ruleDate = purchased.add(Duration(days: days));
      if (ruleDate.isAfter(bestBefore)) return bestBefore;
      return ruleDate;
    }

    if (openDate != null) {
      days = (days * 0.7).round();
      return openDate.add(Duration(days: days));
    }

    return purchased.add(Duration(days: days));
  }
}

/// Enum for impact tracking
enum ImpactType { eaten, fedToPet, trashed }

/// Data model for historical events (cooking/feeding)
class ImpactEvent {
  final DateTime date;
  final ImpactType type;
  final double quantity;
  final String unit;
  final double moneySaved;
  final double co2Saved;

  ImpactEvent({
    required this.date,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.moneySaved,
    required this.co2Saved,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'type': type.name,
      'quantity': quantity,
      'unit': unit,
      'moneySaved': moneySaved,
      'co2Saved': co2Saved,
    };
  }

  factory ImpactEvent.fromJson(Map<String, dynamic> json) {
    return ImpactEvent(
      date: DateTime.parse(json['date'] as String),
      type: ImpactType.values.firstWhere(
        (e) => e.name == (json['type'] as String),
        orElse: () => ImpactType.eaten,
      ),
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      moneySaved: (json['moneySaved'] as num).toDouble(),
      co2Saved: (json['co2Saved'] as num).toDouble(),
    );
  }
}

// ================== Repository ==================

class InventoryRepository extends ChangeNotifier {
  static const _itemsKey = 'inv_items_v1';
  static const _impactKey = 'inv_impact_v1';
  static const _metaKey = 'inv_meta_v1';
  static const _historyKey = 'shopping_history_v1';
  static const _activeShoppingKey = 'shopping_active_v1';

  final List<FoodItem> _items;
  final List<ImpactEvent> _impactEvents;
  final List<ShoppingHistoryItem> _shoppingHistory;
  final List<ShoppingItem> _activeShoppingList;
  final ExpiryService _expiryService = ExpiryService();

  bool hasShownPetWarning = false;
  int _streakDays = 0;
  DateTime? _lastConsumedDate;

  InventoryRepository._(
    this._items, 
    this._impactEvents, 
    this._shoppingHistory, 
    this._activeShoppingList,
  );

  static Future<InventoryRepository> create() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Items
    final itemsJson = prefs.getString(_itemsKey);
    final List<FoodItem> items = [];
    if (itemsJson != null) {
      try {
        final decoded = jsonDecode(itemsJson) as List<dynamic>;
        for (final e in decoded) {
          items.add(FoodItem.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    // 2. Impact Events
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

    // 3. Shopping History
    final historyJson = prefs.getString(_historyKey);
    final List<ShoppingHistoryItem> history = [];
    if (historyJson != null) {
      try {
        final decoded = jsonDecode(historyJson) as List<dynamic>;
        for (final e in decoded) {
          history.add(ShoppingHistoryItem.fromJson(e));
        }
      } catch (_) {}
    }

    // 4. Active Shopping List
    final activeJson = prefs.getString(_activeShoppingKey);
    final List<ShoppingItem> activeList = [];
    if (activeJson != null) {
      try {
        final decoded = jsonDecode(activeJson) as List<dynamic>;
        for (final e in decoded) {
          activeList.add(ShoppingItem.fromJson(e));
        }
      } catch (_) {}
    }

    final repo = InventoryRepository._(items, impactEvents, history, activeList);

    // 5. Meta
    final metaJson = prefs.getString(_metaKey);
    if (metaJson != null) {
      try {
        final m = jsonDecode(metaJson) as Map<String, dynamic>;
        repo._streakDays = (m['streakDays'] as num?)?.toInt() ?? 0;
        final lastIso = m['lastConsumed'] as String?;
        if (lastIso != null) repo._lastConsumedDate = DateTime.tryParse(lastIso);
        repo.hasShownPetWarning = m['petWarningShown'] == true;
      } catch (_) {}
    } 
    
    return repo;
  }

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

  Future<void> _saveHistory() async {
    final prefs = await _prefs();
    final list = _shoppingHistory.map((e) => e.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(list));
  }

  Future<void> _saveActiveShoppingList() async {
    final prefs = await _prefs();
    final list = _activeShoppingList.map((e) => e.toJson()).toList();
    await prefs.setString(_activeShoppingKey, jsonEncode(list));
  }

  Future<void> _saveMeta() async {
    final prefs = await _prefs();
    final meta = {
      'streakDays': _streakDays,
      'lastConsumed': _lastConsumedDate?.toIso8601String(),
      'petWarningShown': hasShownPetWarning,
    };
    await prefs.setString(_metaKey, jsonEncode(meta));
  }

  // ================== 🟢 Shopping Business Logic (New & Clean) ==================

  /// 1. 切换勾选状态
  /// 逻辑：勾选 -> 存入历史；取消勾选 -> 从历史撤销
  Future<void> toggleShoppingItemStatus(ShoppingItem item) async {
    item.isChecked = !item.isChecked;
    
    // 更新本地列表状态
    final index = _activeShoppingList.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _activeShoppingList[index] = item;
    }
    await _saveActiveShoppingList();

    if (item.isChecked) {
      await archiveShoppingItems([item]); // 自动入库历史
    } else {
      await removeRecentHistoryItem(item.name); // 自动撤销历史
    }
    notifyListeners();
  }

  /// 2. 删除物品 (Swipe Delete)
  /// 逻辑：从清单彻底删除。如果它目前是“已勾选”状态，说明用户不想买了/误操作，
  /// 必须把之前自动生成的历史记录也删掉，保持数据一致性。
  Future<void> deleteShoppingItem(ShoppingItem item) async {
    // A. 从清单数据库移除
    _activeShoppingList.removeWhere((i) => i.id == item.id);
    await _saveActiveShoppingList();

    // B. 如果是已勾选状态，视为“反悔”，同步清理历史记录
    if (item.isChecked) {
      await removeRecentHistoryItem(item.name);
    }
    
    notifyListeners();
  }

  /// 3. 结算物品 (Move to Fridge)
  /// 逻辑：移入库存，从清单移除，但【保留】历史记录（因为真的买了）
  Future<void> checkoutShoppingItems(List<ShoppingItem> items) async {
    for (var item in items) {
      // A. 创建库存物品
      StorageLocation loc = StorageLocation.fridge;
      if (item.category == 'pantry') loc = StorageLocation.pantry;
      if (item.category == 'meat') loc = StorageLocation.freezer;
      if (item.category == 'pet') loc = StorageLocation.pantry;
      
      final newItem = FoodItem(
        id: const Uuid().v4(),
        name: item.name,
        location: loc,
        quantity: 1,
        unit: 'pcs',
        purchasedDate: DateTime.now(),
        category: item.category,
      );
      
      // B. 加库存
      _items.add(newItem);
      
      // C. 从清单移除
      _activeShoppingList.removeWhere((i) => i.id == item.id);
    }

    await _saveItems(); // 保存库存
    await _saveActiveShoppingList(); // 保存清单
    notifyListeners();
  }

  /// 4. 基础保存 (Add/Update)
  Future<void> saveShoppingItem(ShoppingItem item) async {
    final index = _activeShoppingList.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _activeShoppingList[index] = item;
    } else {
      _activeShoppingList.add(item);
    }
    await _saveActiveShoppingList();
    notifyListeners();
  }

  /// 5. 获取清单
  List<ShoppingItem> getShoppingList() => List.unmodifiable(_activeShoppingList);

  // ================== Auto-Restock Logic ==================

  Future<void> _checkAutoRefill(FoodItem item) async {
    if (item.minQuantity == null) return;

    if (item.quantity <= item.minQuantity!) {
      final isAlreadyPending = _activeShoppingList.any((s) => 
        s.name.trim().toLowerCase() == item.name.trim().toLowerCase() && 
        !s.isChecked
      );

      if (!isAlreadyPending) {
        final newItem = ShoppingItem(
          id: const Uuid().v4(),
          name: item.name,
          category: item.category ?? 'general',
        );
        await saveShoppingItem(newItem);
        debugPrint('Auto-added low stock item: ${item.name}');
      }
    }
  }

  // ================== Items CRUD ==================

  List<FoodItem> getActiveItems() => _items.where((i) => i.status == FoodStatus.good).toList();

  List<FoodItem> getExpiringItems(int withinDays) {
    return getActiveItems().where((i) => i.daysToExpiry <= withinDays).toList();
  }

  int getSavedCount() => _impactEvents.where((e) => e.type != ImpactType.trashed).length;
  
  int getWastedCount() => _impactEvents.where((e) => e.type == ImpactType.trashed).length;

  Future<void> addItem(FoodItem item) async {
    _items.add(item);
    await _saveItems();
    await _checkAutoRefill(item); 
    notifyListeners();
  }

  Future<void> updateItem(FoodItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
      await _saveItems();
      await _checkAutoRefill(item);
      notifyListeners();
    }
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _saveItems();
    notifyListeners();
  }

  Future<void> updateStatus(String id, FoodStatus status) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = _items[index];
      _items[index] = item.copyWith(status: status);
      await _saveItems();
      
      if (status == FoodStatus.consumed) {
        _updateStreakOnConsumed();
        await _saveMeta();
      }
      notifyListeners();
    }
  }
  
  DateTime predictExpiryForItem(FoodItem base) {
    return _expiryService.predictExpiry(
      base.category,
      base.location,
      base.purchasedDate,
      openDate: base.openDate,
      bestBefore: base.bestBeforeDate,
    );
  }

  // ================== Shopping History Logic ==================

  List<ShoppingHistoryItem> get shoppingHistory {
    final list = List<ShoppingHistoryItem>.from(_shoppingHistory);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> archiveShoppingItems(List<ShoppingItem> items) async {
    final now = DateTime.now();
    for (var item in items) {
      _shoppingHistory.add(ShoppingHistoryItem(
        name: item.name,
        category: item.category,
        date: now,
      ));
    }
    await _saveHistory();
    // notifyListeners called by wrapper
  }

  Future<void> clearHistory() async {
    _shoppingHistory.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> removeRecentHistoryItem(String name) async {
    final index = _shoppingHistory.lastIndexWhere((e) => e.name == name);
    
    if (index != -1) {
      final item = _shoppingHistory[index];
      final now = DateTime.now();
      final diff = now.difference(item.date).inMinutes;

      // 1小时内允许撤销，防止误删历史数据
      if (diff < 60) {
        _shoppingHistory.removeAt(index);
        await _saveHistory();
        // notifyListeners called by wrapper
      }
    }
  }

  // ================== Impact Logic ==================

  List<ImpactEvent> get impactEvents => List.unmodifiable(_impactEvents);

  Future<void> useItemWithImpact(FoodItem item, String action, double usedQty) async {
    if (usedQty <= 0) return;
    final double clamped = usedQty.clamp(0, item.quantity).toDouble();

    await recordImpactForAction(item, action, overrideQty: clamped);

    final remaining = item.quantity - clamped;
    FoodItem updatedItem;

    if (remaining <= 0.0001) {
      updatedItem = item.copyWith(quantity: 0, status: FoodStatus.consumed);
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) _items[index] = updatedItem;
    } else {
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        updatedItem = item.copyWith(quantity: remaining);
        _items[index] = updatedItem;
      } else {
        updatedItem = item;
      }
    }

    await _saveItems();
    await _checkAutoRefill(updatedItem);
    notifyListeners();
  }

  Future<void> recordImpactForAction(FoodItem item, String action, {double? overrideQty}) async {
    final qty = overrideQty ?? item.quantity;
    
    double money = 0;
    double co2 = 0;
    ImpactType type;

    double normalizeQty = qty;
    if (item.unit.toLowerCase() == 'g' || item.unit.toLowerCase() == 'ml') {
      normalizeQty = qty / 1000.0;
    }

    const pricePerKg = 4.0; 
    const co2PerKg = 2.5; 

    switch (action) {
      case 'eat':
        type = ImpactType.eaten;
        money = normalizeQty * pricePerKg;
        co2 = normalizeQty * co2PerKg;
        break;
      case 'pet':
        type = ImpactType.fedToPet;
        money = normalizeQty * pricePerKg; 
        co2 = normalizeQty * (co2PerKg * 0.8);
        break;
      case 'trash':
      default:
        type = ImpactType.trashed;
        money = 0;
        co2 = 0;
        break;
    }

    if (type != ImpactType.trashed) {
      _impactEvents.add(ImpactEvent(
        date: DateTime.now(),
        type: type,
        quantity: qty,
        unit: item.unit,
        moneySaved: money,
        co2Saved: co2,
      ));
      _updateStreakOnConsumed();
      await _saveImpact();
      await _saveMeta();
    }
  }

  Future<void> markPetWarningShown() async {
    if (!hasShownPetWarning) {
      hasShownPetWarning = true;
      await _saveMeta();
    }
  }

  // ================== Streak Logic ==================

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
        _streakDays += 1;
      } else if (diff > 1) {
        _streakDays = 1;
      }
    }
    _lastConsumedDate = today;
  }

  int getCurrentStreakDays() => _streakDays;
}