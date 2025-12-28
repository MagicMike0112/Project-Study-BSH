// lib/repositories/inventory_repository.dart
import 'dart:async';
import 'dart:convert'; 
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/food_item.dart';

// ================== Internal Models ==================

class ShoppingItem {
  final String id;
  final String name;
  final String category;
  bool isChecked;
  // 🟢 新增：谁添加的
  final String? ownerName;

  ShoppingItem({
    required this.id,
    required this.name,
    this.category = 'general',
    this.isChecked = false,
    this.ownerName,
  });

  Map<String, dynamic> toJson(String familyId, String userId) {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'name': name,
      'category': category,
      'is_checked': isChecked,
      'updated_at': DateTime.now().toIso8601String(),
      // 'owner_name' 不需要传给 DB，DB 根据 user_id 关联
    };
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    // 🟢 解析名字逻辑
    String? extractName(Map<String, dynamic> data) {
      if (data['user_profiles'] != null && data['user_profiles'] is Map) {
        return data['user_profiles']['display_name'];
      }
      // 兼容本地缓存结构
      if (data['owner_name'] != null) {
        return data['owner_name'];
      }
      return null;
    }

    return ShoppingItem(
      id: json['id'].toString(),
      name: json['name'],
      category: json['category'] ?? 'general',
      isChecked: json['is_checked'] ?? false,
      ownerName: extractName(json),
    );
  }
  
  // 方便本地序列化缓存 ownerName
  Map<String, dynamic> toLocalJson(String familyId, String userId) {
    var map = toJson(familyId, userId);
    map['owner_name'] = ownerName;
    return map;
  }
}

class ShoppingHistoryItem {
  final String id;
  final String name;
  final String category;
  final DateTime date;

  ShoppingHistoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson(String familyId, String userId) {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'name': name,
      'category': category,
      'added_date': date.toIso8601String(),
    };
  }

  factory ShoppingHistoryItem.fromJson(Map<String, dynamic> json) {
    return ShoppingHistoryItem(
      id: json['id'].toString(),
      name: json['name'],
      category: json['category'] ?? 'general',
      date: DateTime.parse(json['added_date']),
    );
  }
}

class ImpactEvent {
  final String id;
  final DateTime date;
  final ImpactType type;
  final double quantity;
  final String unit;
  final double moneySaved;
  final double co2Saved;

  ImpactEvent({
    required this.id,
    required this.date,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.moneySaved,
    required this.co2Saved,
  });

  Map<String, dynamic> toJson(String familyId, String userId) {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'created_at': date.toIso8601String(),
      'type': type.name,
      'quantity': quantity,
      'unit': unit,
      'money_saved': moneySaved,
      'co2_saved': co2Saved,
    };
  }

  factory ImpactEvent.fromJson(Map<String, dynamic> json) {
    return ImpactEvent(
      id: json['id'].toString(),
      date: DateTime.parse(json['created_at']),
      type: ImpactType.values.firstWhere(
        (e) => e.name == (json['type'] as String),
        orElse: () => ImpactType.eaten,
      ),
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] ?? '',
      moneySaved: (json['money_saved'] as num?)?.toDouble() ?? 0.0,
      co2Saved: (json['co2_saved'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ExpiryService {
  DateTime predictExpiry(String? category, StorageLocation location, DateTime purchased, {DateTime? openDate, DateTime? bestBefore}) {
    int days = 7;
    if (location == StorageLocation.freezer) days = 90;
    else if (location == StorageLocation.pantry) days = 14;
    else if (location == StorageLocation.fridge) days = 5;
    
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

enum ImpactType { eaten, fedToPet, trashed }

// ================== The Repository ==================

class InventoryRepository extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 🟢 新增：Realtime Channel 控制器
  RealtimeChannel? _inventoryChannel;
  RealtimeChannel? _shoppingChannel;

  List<FoodItem> _items = [];
  List<ImpactEvent> _impactEvents = [];
  List<ShoppingHistoryItem> _shoppingHistory = [];
  List<ShoppingItem> _activeShoppingList = [];
  
  final ExpiryService _expiryService = ExpiryService();

  bool hasShownPetWarning = false;
  int _streakDays = 0;

  String? _currentFamilyId;
  String? _currentFamilyName;
  String? _currentUserId;
  // 🟢 新增：当前用户的名字，用于乐观更新 ownerName
  String? _currentUserName; 

  String get currentFamilyName => _currentFamilyName ?? 'My Home';

  InventoryRepository._();

  static Future<InventoryRepository> create() async {
    final repo = InventoryRepository._();
    await repo._loadLocalMeta(); 
    await repo._loadLocalCache(); // 1. 先载入本地数据，UI 立刻有内容
    await repo._initFamilySession();
    repo._fetchAllData(); // 2. 后台静默刷新，不阻塞启动
    return repo;
  }

  // 🟢 新增：销毁时取消订阅
  @override
  void dispose() {
    _supabase.removeChannel(_inventoryChannel!);
    _supabase.removeChannel(_shoppingChannel!);
    super.dispose();
  }

  // ================== Initialization & Cache ==================

  Future<void> _initFamilySession() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    _currentUserId = user.id;

    try {
      // 1. 获取家庭信息
      final response = await _supabase
          .from('family_members')
          .select('family_id, families(name)')
          .eq('user_id', user.id)
          .limit(1); 

      if (response.isNotEmpty) {
        final data = response.first;
        _currentFamilyId = data['family_id'];
        final familyData = data['families'] as Map<String, dynamic>?;
        _currentFamilyName = familyData?['name'];
        debugPrint('Family loaded: $_currentFamilyName');
      } else {
        debugPrint('Creating new family...');
        final newFamilyRes = await _supabase
            .from('families')
            .insert({'name': 'My Home', 'created_by': user.id})
            .select()
            .single();
            
        final newFamilyId = newFamilyRes['id'];

        await _supabase.from('family_members').insert({
          'family_id': newFamilyId,
          'user_id': user.id,
          'role': 'owner',
        });

        _currentFamilyId = newFamilyId;
        _currentFamilyName = 'My Home';
      }

      // 🟢 2. 顺便获取用户名字 (Profile)，用于后续添加物品时自动打标签
      // 假设你的 user_profiles 表的 id 就是 auth.uid()
      try {
        final profileRes = await _supabase
            .from('user_profiles')
            .select('display_name')
            .eq('id', user.id)
            .maybeSingle();
        
        if (profileRes != null) {
          _currentUserName = profileRes['display_name'];
        }
      } catch (e) {
        debugPrint('Profile fetch warning: $e');
      }

      // 🟢 核心：家庭ID确定后，启动实时监听
      if (_currentFamilyId != null) {
        _initRealtimeSubscription();
      }

    } catch (e) {
      debugPrint('Family init critical error: $e');
    }
  }

  // 🟢 核心新增：实时同步逻辑
  void _initRealtimeSubscription() {
    if (_currentFamilyId == null) return;

    debugPrint('🔌 Starting Realtime Sync for family: $_currentFamilyId');

    // 1. 监听库存 (Inventory)
    _inventoryChannel = _supabase.channel('public:inventory_items:$_currentFamilyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // 监听增删改
          schema: 'public',
          table: 'inventory_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'family_id',
            value: _currentFamilyId!,
          ),
          callback: (payload) async {
            await _handleInventoryRealtime(payload);
          },
        )
        .subscribe();

    // 2. 监听购物清单 (Shopping List)
    _shoppingChannel = _supabase.channel('public:shopping_items:$_currentFamilyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'family_id',
            value: _currentFamilyId!,
          ),
          callback: (payload) async {
            await _handleShoppingRealtime(payload);
          },
        )
        .subscribe();
  }

  // 🟢 处理库存变更
  Future<void> _handleInventoryRealtime(PostgresChangePayload payload) async {
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord; // 仅包含 id

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        // 去重：如果本地已经有了（乐观更新导致的），就不加了
        if (_items.any((i) => i.id == newRecord['id'].toString())) return;
        
        // 此时 newRecord 没有 join user_profiles，ownerName 会空
        // 简单策略：先显示，后台悄悄补全信息
        final newItem = FoodItem.fromJson(newRecord);
        _items.insert(0, newItem);
        _fetchOwnerNameForItem(newItem, isShopping: false); // 异步补全名字
        break;

      case PostgresChangeEvent.update:
        final index = _items.indexWhere((i) => i.id == newRecord['id'].toString());
        if (index != -1) {
          // 保留本地的 ownerName，因为 update payload 也没有 profile
          final oldOwnerName = _items[index].ownerName;
          final updatedItem = FoodItem.fromJson(newRecord).copyWith(ownerName: oldOwnerName);
          _items[index] = updatedItem;
        }
        break;

      case PostgresChangeEvent.delete:
        _items.removeWhere((i) => i.id == oldRecord['id'].toString());
        break;
        
      default: break;
    }
    notifyListeners();
    _saveLocalCache();
  }

  // 🟢 处理购物清单变更
  Future<void> _handleShoppingRealtime(PostgresChangePayload payload) async {
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        if (_activeShoppingList.any((i) => i.id == newRecord['id'].toString())) return;
        final newItem = ShoppingItem.fromJson(newRecord);
        _activeShoppingList.add(newItem);
        _fetchOwnerNameForItem(newItem, isShopping: true); // 异步补全名字
        break;

      case PostgresChangeEvent.update:
        final index = _activeShoppingList.indexWhere((i) => i.id == newRecord['id'].toString());
        if (index != -1) {
          // 保留旧名字
          final oldOwner = _activeShoppingList[index].ownerName;
          // 注意：ShoppingItem 是 final，需要创建一个新的
          // 这里的 fromJson 同样没有名字，我们需要手动补上旧名字
          ShoppingItem updatedItem = ShoppingItem.fromJson(newRecord);
          // 使用旧名字替换 null
          updatedItem = ShoppingItem(
            id: updatedItem.id,
            name: updatedItem.name,
            category: updatedItem.category,
            isChecked: updatedItem.isChecked,
            ownerName: oldOwner, // 保持 owner 不变
          );
          _activeShoppingList[index] = updatedItem;
        }
        break;

      case PostgresChangeEvent.delete:
        _activeShoppingList.removeWhere((i) => i.id == oldRecord['id'].toString());
        break;
        
      default: break;
    }
    notifyListeners();
    _saveLocalCache();
  }

  // 🟢 辅助：为 Realtime 新增的物品补全 ownerName
  // 因为 Realtime 推送的是 raw table data，没有关联查询
  Future<void> _fetchOwnerNameForItem(dynamic item, {required bool isShopping}) async {
    try {
      final table = isShopping ? 'shopping_items' : 'inventory_items';
      final res = await _supabase
          .from(table)
          .select('user_profiles(display_name)')
          .eq('id', item.id)
          .single();
      
      final name = res['user_profiles']?['display_name'];
      if (name != null) {
        if (!isShopping) {
          final index = _items.indexWhere((i) => i.id == item.id);
          if (index != -1) {
            _items[index] = _items[index].copyWith(ownerName: name);
          }
        } else {
          final index = _activeShoppingList.indexWhere((i) => i.id == item.id);
          if (index != -1) {
            final old = _activeShoppingList[index];
            _activeShoppingList[index] = ShoppingItem(
              id: old.id, name: old.name, category: old.category, isChecked: old.isChecked,
              ownerName: name,
            );
          }
        }
        notifyListeners(); // 名字回来后再次刷新
        _saveLocalCache();
      }
    } catch (_) {}
  }

  Future<void> _ensureFamily() async {
    if (_currentFamilyId != null) return;
    await _initFamilySession();
  }

  Future<void> _fetchAllData() async {
    try {
      if (_currentFamilyId == null) return;

      // 🟢 修改查询：关联 user_profiles 获取 ownerName
      final itemsData = await _supabase
          .from('inventory_items')
          .select('*, user_profiles(display_name)') // 关联查询
          .eq('family_id', _currentFamilyId!)
          .order('created_at', ascending: false);
      _items = (itemsData as List).map((e) => FoodItem.fromJson(e)).toList();

      // 🟢 Shopping List 同理
      final shoppingData = await _supabase
          .from('shopping_items')
          .select('*, user_profiles(display_name)') // 关联查询
          .eq('family_id', _currentFamilyId!)
          .order('created_at', ascending: true);
      _activeShoppingList = (shoppingData as List).map((e) => ShoppingItem.fromJson(e)).toList();

      final historyData = await _supabase.from('shopping_history').select().eq('family_id', _currentFamilyId!).order('added_date', ascending: false);
      _shoppingHistory = (historyData as List).map((e) => ShoppingHistoryItem.fromJson(e)).toList();

      final impactData = await _supabase.from('impact_events').select().eq('family_id', _currentFamilyId!).order('created_at', ascending: false);
      _impactEvents = (impactData as List).map((e) => ImpactEvent.fromJson(e)).toList();

      _calculateStreakFromLocalEvents();
      await _saveLocalCache(); // Sync network data to local
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fid = _currentFamilyId ?? '';
      final uid = _currentUserId ?? '';

      final itemsJson = jsonEncode(_items.map((e) => e.toJson()).toList());
      // 使用 toLocalJson 来保存 ownerName 到本地
      final shoppingJson = jsonEncode(_activeShoppingList.map((e) => e.toLocalJson(fid, uid)).toList());
      final historyJson = jsonEncode(_shoppingHistory.map((e) => e.toJson(fid, uid)).toList());
      final impactJson = jsonEncode(_impactEvents.map((e) => e.toJson(fid, uid)).toList());

      await prefs.setString('cache_inventory', itemsJson);
      await prefs.setString('cache_shopping', shoppingJson);
      await prefs.setString('cache_history', historyJson);
      await prefs.setString('cache_impact', impactJson);
    } catch (e) { debugPrint('Save cache error: $e'); }
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final itemsStr = prefs.getString('cache_inventory');
      if (itemsStr != null) _items = (jsonDecode(itemsStr) as List).map((e) => FoodItem.fromJson(e)).toList();

      final shoppingStr = prefs.getString('cache_shopping');
      if (shoppingStr != null) _activeShoppingList = (jsonDecode(shoppingStr) as List).map((e) => ShoppingItem.fromJson(e)).toList();

      final historyStr = prefs.getString('cache_history');
      if (historyStr != null) _shoppingHistory = (jsonDecode(historyStr) as List).map((e) => ShoppingHistoryItem.fromJson(e)).toList();

      final impactStr = prefs.getString('cache_impact');
      if (impactStr != null) {
        _impactEvents = (jsonDecode(impactStr) as List).map((e) => ImpactEvent.fromJson(e)).toList();
        _calculateStreakFromLocalEvents();
      }

      notifyListeners();
    } catch (e) { debugPrint('Load cache error: $e'); }
  }

  // ================== Inventory CRUD ==================

  List<FoodItem> getActiveItems() => _items.where((i) => i.status == FoodStatus.good).toList();
  List<FoodItem> getExpiringItems(int withinDays) => getActiveItems().where((i) => i.daysToExpiry <= withinDays).toList();

  Future<void> addItem(FoodItem item) async {
    // 🟢 1. 乐观更新：给 item 加上当前用户的名字
    final itemWithUser = item.copyWith(ownerName: _currentUserName);
    
    _items.insert(0, itemWithUser);
    notifyListeners();
    _saveLocalCache(); 

    // 2. 后台异步同步 Supabase
    try {
      await _ensureFamily();
      if (_currentFamilyId == null) return; 

      final json = item.toJson();
      json['family_id'] = _currentFamilyId; 
      json['user_id'] = _currentUserId; 
      
      await _supabase.from('inventory_items').insert(json);
      await _checkAutoRefill(item);
    } catch (e) {
      debugPrint('Add item network error: $e');
    }
  }

  Future<void> updateItem(FoodItem item) async {
    // 🟢 乐观更新
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
      _saveLocalCache();
    }

    try {
      await _ensureFamily();
      if (_currentFamilyId == null) return;
      
      final json = item.toJson();
      json['family_id'] = _currentFamilyId;
      
      await _supabase.from('inventory_items').update(json).eq('id', item.id);
      await _checkAutoRefill(item);
    } catch (e) { debugPrint('Update error: $e'); }
  }

  Future<void> deleteItem(String id) async {
    // 🟢 乐观更新
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    _saveLocalCache();

    try {
      await _supabase.from('inventory_items').delete().eq('id', id);
    } catch (e) { debugPrint('Delete error: $e'); }
  }

  Future<void> updateStatus(String id, FoodStatus status) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final updatedItem = _items[index].copyWith(status: status);
      await updateItem(updatedItem); 
      if (status == FoodStatus.consumed) _updateStreakOnConsumed();
    }
  }

  // ================== Shopping List (重点修复延迟部分) ==================

  List<ShoppingItem> getShoppingList() => List.unmodifiable(_activeShoppingList);

  Future<void> saveShoppingItem(ShoppingItem item) async {
    // 🟢 1. 乐观更新：如果是新增，附加上当前用户的名字
    ShoppingItem optimisticItem = item;
    if (item.ownerName == null && _currentUserName != null) {
        optimisticItem = ShoppingItem(
            id: item.id,
            name: item.name,
            category: item.category,
            isChecked: item.isChecked,
            ownerName: _currentUserName // 加上名字
        );
    }

    final index = _activeShoppingList.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _activeShoppingList[index] = optimisticItem;
    } else {
      _activeShoppingList.add(optimisticItem);
    }
    
    notifyListeners(); // 界面瞬间响应
    _saveLocalCache(); // 存本地

    // 2. 后台处理网络请求
    try {
      await _ensureFamily();
      if (_currentFamilyId == null || _currentUserId == null) return;

      await _supabase.from('shopping_items').upsert(
        item.toJson(_currentFamilyId!, _currentUserId!)
      );
    } catch (e) { debugPrint('Save shopping network error: $e'); }
  }

  Future<void> toggleShoppingItemStatus(ShoppingItem item) async {
    item.isChecked = !item.isChecked;
    await saveShoppingItem(item); 
    
    if (item.isChecked) await archiveShoppingItems([item]);
    else await removeRecentHistoryItem(item.name);
  }

  Future<void> deleteShoppingItem(ShoppingItem item) async {
    // 🟢 乐观更新
    _activeShoppingList.removeWhere((i) => i.id == item.id);
    notifyListeners();
    _saveLocalCache();

    try {
      await _supabase.from('shopping_items').delete().eq('id', item.id);
      if (item.isChecked) await removeRecentHistoryItem(item.name);
    } catch (e) { debugPrint('Delete shopping error: $e'); }
  }

  Future<void> checkoutShoppingItems(List<ShoppingItem> items) async {
    // 1. 先把物品加到 Inventory (乐观)
    for (var item in items) {
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
        source: 'shopping_list',
        ownerName: item.ownerName // 继承购物清单里的 ownerName
      );
      // addItem 内部已经包含 notify 和 saveLocal
      await addItem(newItem); 
      
      // 2. 从 Shopping List 移除 (乐观)
      _activeShoppingList.removeWhere((i) => i.id == item.id);
      
      // 后台删 Shopping List 记录
      try {
        await _supabase.from('shopping_items').delete().eq('id', item.id);
      } catch (e) { debugPrint('Checkout delete error: $e'); }
    }
    
    notifyListeners();
    _saveLocalCache();
  }

  // ================== History & Impact ==================

  List<ShoppingHistoryItem> get shoppingHistory {
    final list = List<ShoppingHistoryItem>.from(_shoppingHistory);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> archiveShoppingItems(List<ShoppingItem> items) async {
    // 🟢 乐观更新
    final now = DateTime.now();
    for (var item in items) {
      final historyItem = ShoppingHistoryItem(
        id: const Uuid().v4(),
        name: item.name,
        category: item.category,
        date: now,
      );
      _shoppingHistory.insert(0, historyItem);
      
      // 网络异步操作
      _ensureFamily().then((_) {
        if (_currentFamilyId != null && _currentUserId != null) {
           _supabase.from('shopping_history').insert(
            historyItem.toJson(_currentFamilyId!, _currentUserId!)
          );
        }
      });
    }
    notifyListeners();
    _saveLocalCache();
  }

  Future<void> removeRecentHistoryItem(String name) async {
    // 🟢 乐观更新
    final index = _shoppingHistory.indexWhere((e) => e.name == name);
    if (index != -1) {
      final item = _shoppingHistory[index];
      if (DateTime.now().difference(item.date).inMinutes < 60) {
        _shoppingHistory.removeAt(index);
        notifyListeners();
        _saveLocalCache();

        try {
          await _supabase.from('shopping_history').delete().eq('id', item.id);
        } catch (e) { debugPrint('Remove history error: $e'); }
      }
    }
  }

  Future<void> clearHistory() async {
    // 🟢 乐观更新
    _shoppingHistory.clear();
    notifyListeners();
    _saveLocalCache();
    
    try {
      if (_currentFamilyId != null) {
        await _supabase.from('shopping_history').delete().eq('family_id', _currentFamilyId!);
      }
    } catch (e) { debugPrint('Clear history error: $e'); }
  }

  List<ImpactEvent> get impactEvents => List.unmodifiable(_impactEvents);
  int getSavedCount() => _impactEvents.where((e) => e.type != ImpactType.trashed).length;
  int getWastedCount() => _impactEvents.where((e) => e.type == ImpactType.trashed).length;

  Future<void> useItemWithImpact(FoodItem item, String action, double usedQty) async {
    if (usedQty <= 0) return;
    final double clamped = usedQty.clamp(0, item.quantity).toDouble();
    await recordImpactForAction(item, action, overrideQty: clamped);

    final remaining = item.quantity - clamped;
    if (remaining <= 0.0001) {
      await updateStatus(item.id, FoodStatus.consumed); 
    } else {
      await updateItem(item.copyWith(quantity: remaining));
    }
  }

  Future<void> recordImpactForAction(FoodItem item, String action, {double? overrideQty}) async {
    final qty = overrideQty ?? item.quantity;
    double money = 0; double co2 = 0; ImpactType type;
    double normalizeQty = qty;
    
    if (item.unit.toLowerCase() == 'g' || item.unit.toLowerCase() == 'ml') normalizeQty = qty / 1000.0;
    
    switch (action) {
      case 'eat': 
        type = ImpactType.eaten; 
        money = normalizeQty * 4.0; 
        co2 = normalizeQty * 2.5; 
        break;
      case 'pet': 
        type = ImpactType.fedToPet; 
        money = normalizeQty * 4.0; 
        co2 = normalizeQty * 2.0; 
        break;
      default: 
        type = ImpactType.trashed; 
        break;
    }

    if (type != ImpactType.trashed) {
      final event = ImpactEvent(
        id: const Uuid().v4(),
        date: DateTime.now(),
        type: type,
        quantity: qty,
        unit: item.unit,
        moneySaved: money,
        co2Saved: co2,
      );
      
      // 🟢 乐观更新
      _impactEvents.insert(0, event);
      _updateStreakOnConsumed();
      _saveMeta(); 
      notifyListeners();
      _saveLocalCache();

      try {
        await _ensureFamily();
        if (_currentFamilyId != null && _currentUserId != null) {
          await _supabase.from('impact_events').insert(
            event.toJson(_currentFamilyId!, _currentUserId!)
          );
        }
      } catch (e) { debugPrint('Impact error: $e'); }
    }
  }

  // ================== Meta / Helper ==================
  
  Future<void> _checkAutoRefill(FoodItem item) async {
    if (item.minQuantity == null) return;
    if (item.quantity <= item.minQuantity!) {
      final isPending = _activeShoppingList.any((s) => s.name.toLowerCase() == item.name.toLowerCase() && !s.isChecked);
      if (!isPending) {
        final newItem = ShoppingItem(id: const Uuid().v4(), name: item.name, category: item.category ?? 'general');
        await saveShoppingItem(newItem);
      }
    }
  }

  Future<void> _loadLocalMeta() async {
    final prefs = await SharedPreferences.getInstance();
    hasShownPetWarning = prefs.getBool('petWarningShown') ?? false;
    _streakDays = prefs.getInt('streakDays') ?? 0;
  }
  
  Future<void> _saveMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('petWarningShown', hasShownPetWarning);
    await prefs.setInt('streakDays', _streakDays);
  }
  
  void _calculateStreakFromLocalEvents() { if (_impactEvents.isNotEmpty) _streakDays = 1; }
  void _updateStreakOnConsumed() { _streakDays++; }
  int getCurrentStreakDays() => _streakDays;

  Future<void> markPetWarningShown() async { 
    hasShownPetWarning = true; 
    await _saveMeta(); 
  }

  // ================== Family Management ==================
  
  Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    await _ensureFamily();
    if (_currentFamilyId == null) return [];
    try {
      final res = await _supabase.from('family_members').select('role, user_id, user_profiles(display_name)').eq('family_id', _currentFamilyId!);
      return (res as List).map((e) {
        final profile = e['user_profiles'] as Map<String, dynamic>?;
        return {
          'user_id': e['user_id'],
          'role': e['role'],
          'name': profile?['display_name'] ?? 'Unknown User',
        };
      }).toList();
    } catch (e) { return []; }
  }

  Future<String> createInviteCode() async {
    await _ensureFamily();
    if (_currentFamilyId == null) throw Exception("System Error");
    final code = (100000 + Random().nextInt(900000)).toString();
    await _supabase.from('family_invites').insert({'family_id': _currentFamilyId, 'inviter_id': _currentUserId, 'code': code});
    return code;
  }

  Future<bool> joinFamily(String code) async {
    if (_currentUserId == null) return false;
    try {
      final invite = await _supabase.from('family_invites').select().eq('code', code).gt('expires_at', DateTime.now().toIso8601String()).maybeSingle();
      if (invite == null) return false;
      await _supabase.from('family_members').insert({'family_id': invite['family_id'], 'user_id': _currentUserId, 'role': 'member'});
      await _initFamilySession();
      await _fetchAllData();
      return true;
    } catch (e) { return false; }
  }
}