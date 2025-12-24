// lib/repositories/inventory_repository.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';

// ================== Models ==================

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
  static const _historyKey = 'shopping_history_v1'; // 🆕

  final List<FoodItem> _items;
  final List<ImpactEvent> _impactEvents;
  final List<ShoppingHistoryItem> _shoppingHistory; // 🆕
  final ExpiryService _expiryService = ExpiryService();

  bool hasShownPetWarning = false;
  int _streakDays = 0;
  DateTime? _lastConsumedDate;

  InventoryRepository._(this._items, this._impactEvents, this._shoppingHistory);

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

    // 3. Shopping History (New)
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

    final repo = InventoryRepository._(items, impactEvents, history);

    // 4. Meta
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

  Future<void> _saveHistory() async { // 🆕
    final prefs = await _prefs();
    final list = _shoppingHistory.map((e) => e.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(list));
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
    notifyListeners();
  }

  Future<void> updateItem(FoodItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
      await _saveItems();
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
      
      // Update streak if consumed
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

  // ================== Shopping History Logic (New) ==================

  List<ShoppingHistoryItem> get shoppingHistory {
    final list = List<ShoppingHistoryItem>.from(_shoppingHistory);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> archiveShoppingItems(List<dynamic> items) async {
    final now = DateTime.now();
    for (var item in items) {
      // 假设 item 是 ShoppingItem，有 name 和 category 属性
      _shoppingHistory.add(ShoppingHistoryItem(
        name: item.name,
        category: item.category,
        date: now,
      ));
    }
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _shoppingHistory.clear();
    await _saveHistory();
    notifyListeners();
  }

  // ================== Impact Logic ==================

  List<ImpactEvent> get impactEvents => List.unmodifiable(_impactEvents);

  Future<void> useItemWithImpact(FoodItem item, String action, double usedQty) async {
    if (usedQty <= 0) return;
    final double clamped = usedQty.clamp(0, item.quantity).toDouble();

    await recordImpactForAction(item, action, overrideQty: clamped);

    final remaining = item.quantity - clamped;
    if (remaining <= 0.0001) {
      await updateStatus(item.id, FoodStatus.consumed);
    } else {
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _items[index] = item.copyWith(quantity: remaining);
        await _saveItems();
        notifyListeners();
      }
    }
  }

  Future<void> recordImpactForAction(FoodItem item, String action, {double? overrideQty}) async {
    final qty = overrideQty ?? item.quantity;
    
    // Estimation logic
    double money = 0;
    double co2 = 0;
    ImpactType type;

    // Simple heuristic for units
    double normalizeQty = qty;
    if (item.unit.toLowerCase() == 'g' || item.unit.toLowerCase() == 'ml') {
      normalizeQty = qty / 1000.0; // convert to kg/L for price calc
    }

    const pricePerKg = 4.0; // avg food price
    const co2PerKg = 2.5;   // avg carbon footprint

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
      notifyListeners();
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