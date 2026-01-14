// lib/repositories/inventory_repository.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http; 

import '../models/food_item.dart';
import '../utils/impact_calculator.dart';

// ================== 新增的 Imports ==================
// 引入拆分出去的模型和服务
import '../models/shopping_item.dart';
import '../models/shopping_history_item.dart';
import '../models/impact_event.dart';
import '../services/expiry_service.dart';

// ================== Exports ==================
// 保持对外的兼容性，让引用了 InventoryRepository 的文件无需修改 imports
export '../models/shopping_item.dart';
export '../models/shopping_history_item.dart';
export '../models/impact_event.dart';

// ================== The Repository ==================

class InventoryRepository extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _inventoryChannel;
  RealtimeChannel? _shoppingChannel;
  StreamSubscription<AuthState>? _authSubscription;

  List<FoodItem> _items = [];
  List<ImpactEvent> _impactEvents = [];
  List<ShoppingHistoryItem> _shoppingHistory = [];
  List<ShoppingItem> _activeShoppingList = [];
  
  List<Map<String, dynamic>> _pendingUploads = [];

  final ExpiryService _expiryService = ExpiryService();

  bool hasShownPetWarning = false;
  int _streakDays = 0;

  // 家庭模式状态
  bool _isSharedUsage = true;
  bool get isSharedUsage => _isSharedUsage;
  
  String? _currentFamilyId;
  String? _currentFamilyName;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserEmail;

  Completer<void>? _sessionCompleter;
  bool get _isLoggedIn => _supabase.auth.currentUser != null;

  // Key: User ID, Value: Display Name
  Map<String, String> _familyMemberCache = {};

  String get currentFamilyName => _currentFamilyName ?? 'My Home';
  String get currentUserName => _currentUserName ?? _currentUserEmail ?? 'User';

  InventoryRepository._() {
    _initAuthListener();
  }

  static Future<InventoryRepository> create() async {
    final repo = InventoryRepository._();
    await repo._loadLocalMeta();
    await repo._loadLocalCache();
    
    repo._initFamilySession().then((_) {
      repo._fetchAllData();
    }).catchError((e) {
      debugPrint("Background init error: $e");
    });
    
    return repo;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cleanupRealtime();
    super.dispose();
  }

  // 切换家庭模式
  Future<void> setSharedUsageMode(bool isShared) async {
    _isSharedUsage = isShared;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_shared_usage_v1', isShared);
  }

  Future<DateTime?> predictExpiryDate(String name, String location, DateTime purchasedDate) async {
    const String baseUrl = 'https://project-study-bsh.vercel.app'; 
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recipe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'location': location, 
          'purchasedDate': purchasedDate.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['predictedExpiry'] != null) {
          return DateTime.tryParse(data['predictedExpiry']);
        }
      }
    } catch (e) {
      debugPrint("AI Prediction Error: $e");
    }
    return null; 
  }

  void _cleanupRealtime() {
    if (_inventoryChannel != null) _supabase.removeChannel(_inventoryChannel!);
    if (_shoppingChannel != null) _supabase.removeChannel(_shoppingChannel!);
    _inventoryChannel = null;
    _shoppingChannel = null;
  }

  void _initAuthListener() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _sessionCompleter = null; 
        await _initFamilySession();
        await _fetchAllData();
      } else if (event == AuthChangeEvent.signedOut) {
        _resetState(keepLocal: true);
        notifyListeners();
      }
    });
  }

  void _resetState({bool keepLocal = false}) {
    _cleanupRealtime();
    _currentUserId = null;
    _currentFamilyId = null;
    _currentFamilyName = null;
    _currentUserName = null;
    _currentUserEmail = null;
    _familyMemberCache.clear();
    if (!keepLocal) {
      _items = [];
      _activeShoppingList = [];
      _shoppingHistory = [];
      _impactEvents = [];
      _pendingUploads = [];
    }
    _sessionCompleter = null;
  }

  Future<void> _initFamilySession() async {
    if (_sessionCompleter != null) {
      if (!_sessionCompleter!.isCompleted) return _sessionCompleter!.future;
      return; 
    }
    
    _sessionCompleter = Completer<void>();

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _resetState(keepLocal: true);
        return;
      }

      _currentUserId = user.id;
      _currentUserEmail = user.email;
      _currentUserName = user.userMetadata?['display_name'];
      if (_currentUserName == null || _currentUserName!.isEmpty) {
        _currentUserName = _currentUserEmail;
      }
      try {
        final profile = await _supabase.from('user_profiles').select('display_name').eq('id', user.id).maybeSingle();
        final profileName = profile?['display_name'];
        if (profileName != null && profileName.toString().isNotEmpty) {
          _currentUserName = profileName;
        }
      } catch (_) {}

      final response = await _supabase
          .from('family_members')
          .select('family_id, families(name)')
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _currentFamilyId = response['family_id'];
        _currentFamilyName = response['families']['name'];
      } else {
        await _createNewDefaultFamily(user.id);
      }

      if (_currentFamilyId != null) {
        await _refreshFamilyMemberCache();
        _initRealtimeSubscription();
      }

    } catch (e) {
      debugPrint('🚨 Session Init Error: $e');
      if (_currentUserId != null && _currentFamilyId == null) {
         await _createNewDefaultFamily(_currentUserId!);
      }
    } finally {
      if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
        _sessionCompleter!.complete();
      }
    }
  }

  Future<void> _createNewDefaultFamily(String userId) async {
    try {
      final newFamily = await _supabase
          .from('families')
          .insert({'name': 'My Home', 'created_by': userId})
          .select()
          .single();

      final fid = newFamily['id'];
      await _supabase.from('family_members').insert({
        'family_id': fid,
        'user_id': userId,
        'role': 'owner',
      });
      
      _currentFamilyId = fid;
      _currentFamilyName = 'My Home';
    } catch (e) {
      debugPrint('🚨 Failed to create default family: $e');
    }
  }

  Future<void> _fetchAllData() async {
    await _ensureFamily();
    if (_currentFamilyId == null) return;

    await _processPendingQueue();

    try {
      _refreshFamilyMemberCache().catchError((e) => debugPrint("Member cache error: $e"));

      final results = await Future.wait([
        _supabase.from('inventory_items').select('*, user_profiles(display_name, email)').eq('family_id', _currentFamilyId!).order('created_at', ascending: false),
        _supabase.from('shopping_items').select('*, user_profiles(display_name, email)').eq('family_id', _currentFamilyId!).order('created_at', ascending: true),
        _supabase.from('shopping_history').select().eq('family_id', _currentFamilyId!).order('added_date', ascending: false),
        _supabase.from('impact_events').select().eq('family_id', _currentFamilyId!).order('created_at', ascending: false),
      ]);

      // Merge Inventory
      final serverItems = (results[0] as List).map((e) {
        try { return FoodItem.fromJson(_injectFallbackName(e)); } catch (_) { return null; }
      }).whereType<FoodItem>().toList();

      final pendingInventory = _pendingUploads
          .where((e) => (e['meta_table'] == 'inventory_items' || e['meta_table'] == null))
          .map((e) {
             try { return FoodItem.fromJson(_injectFallbackName(e)); } catch(_) { return null; }
          })
          .whereType<FoodItem>()
          .where((local) => !serverItems.any((server) => server.id == local.id))
          .toList();
      
      _items = [...pendingInventory, ...serverItems];

      // Merge Shopping List
      final serverShopping = (results[1] as List).map((e) {
         try { return ShoppingItem.fromJson(_injectFallbackName(e)); } catch (_) { return null; }
      }).whereType<ShoppingItem>().toList();

      final pendingShopping = _pendingUploads
          .where((e) => e['meta_table'] == 'shopping_items')
          .map((e) {
             try { return ShoppingItem.fromJson(_injectFallbackName(e)); } catch (_) { return null; }
          })
          .whereType<ShoppingItem>()
          .where((local) => !serverShopping.any((server) => server.id == local.id))
          .toList();

      _activeShoppingList = [...pendingShopping, ...serverShopping];

      _shoppingHistory = (results[2] as List).map((e) => ShoppingHistoryItem.fromJson(e)).toList();
      _impactEvents = (results[3] as List).map((e) => ImpactEvent.fromJson(e)).toList();

      _calculateStreakFromLocalEvents();
      await _saveLocalCache();
      notifyListeners();
    } catch (e) {
      debugPrint('🚨 Fetch Data Error: $e');
    }
  }

  Future<void> _ensureFamily() async {
    if (_currentFamilyId != null) return;
    
    if (_sessionCompleter != null) {
       await _sessionCompleter!.future;
    } else {
       await _initFamilySession();
    }
  }

  void _initRealtimeSubscription() {
    if (_currentFamilyId == null) return;
    _cleanupRealtime();

    _inventoryChannel = _supabase.channel('public:inventory:$_currentFamilyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'family_id', value: _currentFamilyId!),
          callback: (payload) => _handleInventoryRealtime(payload),
        ).subscribe();

    _shoppingChannel = _supabase.channel('public:shopping:$_currentFamilyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_items',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'family_id', value: _currentFamilyId!),
          callback: (payload) => _handleShoppingRealtime(payload),
        ).subscribe();
  }

  void _handleInventoryRealtime(PostgresChangePayload payload) {
    if (_currentFamilyId == null) return;
    final newRec = payload.newRecord;
    final oldRec = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.insert) {
      if (!_items.any((i) => i.id == newRec['id'])) {
        _items.insert(0, FoodItem.fromJson(_injectFallbackName(newRec)));
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final idx = _items.indexWhere((i) => i.id == newRec['id']);
      if (idx != -1) _items[idx] = FoodItem.fromJson(_injectFallbackName(newRec));
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      _items.removeWhere((i) => i.id == oldRec['id']);
    }
    _saveLocalCache();
    notifyListeners();
  }

  void _handleShoppingRealtime(PostgresChangePayload payload) {
    if (_currentFamilyId == null) return;
    final newRec = payload.newRecord;
    final oldRec = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.insert) {
      if (!_activeShoppingList.any((i) => i.id == newRec['id'])) {
        _activeShoppingList.add(ShoppingItem.fromJson(_injectFallbackName(newRec)));
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final idx = _activeShoppingList.indexWhere((i) => i.id == newRec['id']);
      if (idx != -1) _activeShoppingList[idx] = ShoppingItem.fromJson(_injectFallbackName(newRec));
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      _activeShoppingList.removeWhere((i) => i.id == oldRec['id']);
    }
    _saveLocalCache();
    notifyListeners();
  }

  Map<String, dynamic> _injectFallbackName(Map<String, dynamic> json) {
    if (json['user_profiles'] != null) return json;
    final uid = json['user_id']?.toString();
    String name = 'Family';
    if (_currentUserId != null && uid == _currentUserId) {
      name = currentUserName;
    } else if (uid != null) {
      name = _familyMemberCache[uid] ?? 'Family';
    }
    
    final newMap = Map<String, dynamic>.from(json);
    newMap['user_profiles'] = {'display_name': name};
    return newMap;
  }

  Map<String, dynamic> _cleanJsonForDb(Map<String, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    json.remove('user_profiles');
    json.remove('owner_name');
    json.remove('ownerName'); 
    json.remove('display_name');
    json.remove('meta_table'); 

    if (_currentFamilyId != null) json['family_id'] = _currentFamilyId;
    
    // 只有当 user_id 不存在且当前用户可用时，才默认使用当前用户
    if (!json.containsKey('user_id') && _currentUserId != null) {
      json['user_id'] = _currentUserId;
    }

    return json;
  }

  Future<void> _processPendingQueue() async {
    if (_pendingUploads.isEmpty) return;
    if (_currentFamilyId == null) return;

    final List<Map<String, dynamic>> queue = List.from(_pendingUploads);
    final List<Map<String, dynamic>> successful = [];

    for (var itemWithMeta in queue) {
      try {
        final tableName = itemWithMeta['meta_table'] ?? 'inventory_items';
        final itemJson = Map<String, dynamic>.from(itemWithMeta);
        
        itemJson['family_id'] = _currentFamilyId;
        if (itemJson['user_id'] == null || itemJson['user_id'].toString().isEmpty) {
          itemJson['user_id'] = _currentUserId;
        }
        
        final payload = _cleanJsonForDb(itemJson);
        await _supabase.from(tableName).upsert(payload).timeout(const Duration(seconds: 5));
        successful.add(itemWithMeta);
      } catch (e) {
        debugPrint("❌ Sync failed for item: $e");
      }
    }

    if (successful.isNotEmpty) {
      _pendingUploads.removeWhere((pending) => successful.contains(pending));
      await _saveLocalCache();
    }
  }

  Future<void> _queueOfflineAction(String tableName, Map<String, dynamic> rawJson) async {
    final payload = _cleanJsonForDb(rawJson);
    if (payload['user_id'] == null || payload['user_id'].toString().isEmpty) {
      payload.remove('user_id');
    }
    payload['meta_table'] = tableName;
    
    final idx = _pendingUploads.indexWhere((e) => e['id'] == payload['id']);
    if (idx != -1) {
      _pendingUploads[idx] = payload;
    } else {
      _pendingUploads.add(payload);
    }
    await _saveLocalCache();
  }

  List<FoodItem> getActiveItems() => _items.where((i) => i.status == FoodStatus.good).toList();
  List<FoodItem> getExpiringItems(int days) => getActiveItems().where((i) => i.daysToExpiry <= days).toList();

  Future<void> addItem(FoodItem item) async {
    final effectiveOwner = currentUserName;
    final optimisticItem = item.copyWith(ownerName: effectiveOwner);
    _items.insert(0, optimisticItem);
    notifyListeners();
    await _saveLocalCache();
    if (!_isLoggedIn) {
      await _queueOfflineAction('inventory_items', item.toJson());
      return;
    }

    try {
      await _ensureFamily();
      if (_currentFamilyId == null) throw Exception("Cannot sync: No family context");
      
      var payload = optimisticItem.toJson();
      if (!_isSharedUsage) {
         payload['user_id'] = _currentUserId;
      }
      payload = _cleanJsonForDb(payload);
      
      await _supabase.from('inventory_items').insert(payload).timeout(const Duration(seconds: 5));
      await _checkAutoRefill(item);
    } catch (e) {
      await _queueOfflineAction('inventory_items', item.toJson());
    }
  }

  Future<void> updateItem(FoodItem item) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) _items[idx] = item;
    notifyListeners();
    await _saveLocalCache();
    if (!_isLoggedIn) {
      await _queueOfflineAction('inventory_items', item.toJson());
      return;
    }

    try {
      await _ensureFamily();
      final payload = _cleanJsonForDb(item.toJson());
      payload.remove('created_at');
      
      payload.remove('user_id'); 

      await _supabase.from('inventory_items').update(payload).eq('id', item.id).timeout(const Duration(seconds: 5));
      await _checkAutoRefill(item);
    } catch (e) {
      await _queueOfflineAction('inventory_items', item.toJson());
    }
  }

  Future<void> assignItemToUser(String itemId, String memberName) async {
    String? targetUserId;
    if (memberName == 'Family' || memberName == 'Shared') {
      targetUserId = _currentUserId; 
    } else {
      final entry = _familyMemberCache.entries.firstWhere(
        (e) => e.value == memberName, 
        orElse: () => const MapEntry('', ''),
      );
      targetUserId = entry.key.isNotEmpty ? entry.key : _currentUserId;
    }

    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(ownerName: memberName);
      notifyListeners();
      await _saveLocalCache();
    }

    try {
      await _ensureFamily();
      if (targetUserId != null) {
        await _supabase.from('inventory_items')
            .update({'user_id': targetUserId})
            .eq('id', itemId);
      }
    } catch (e) {
      debugPrint("Assign failed: $e");
    }
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    await _saveLocalCache();

    try {
      await _supabase.from('inventory_items').delete().eq('id', id).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Delete sync error: $e');
    }
  }

  Future<void> updateStatus(String id, FoodStatus status) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final updatedItem = _items[index].copyWith(status: status);
      await updateItem(updatedItem);
      if (status == FoodStatus.consumed) _updateStreakOnConsumed();
    }
  }

  Future<void> useItemWithImpact(FoodItem item, String action, double usedQty) async {
    if (usedQty <= 0) return;
    
    // 🟢 核心优化：处理浮点数计算误差
    // 1. Clamp 限制范围
    double clamped = usedQty.clamp(0, item.quantity).toDouble();
    // 2. 强制保留2位小数，防止出现 1.200000001 这种情况
    clamped = double.parse(clamped.toStringAsFixed(2));
    
    await recordImpactForAction(item, action, overrideQty: clamped);

    // 3. 计算剩余量，并同样强制保留2位小数
    double remaining = item.quantity - clamped;
    remaining = double.parse(remaining.toStringAsFixed(2));

    if (remaining <= 0.0001) {
      await updateStatus(item.id, FoodStatus.consumed);
    } else {
      await updateItem(item.copyWith(quantity: remaining));
    }
  }
  
  Future<void> undoConsume(FoodItem oldItem, String? eventId) async {
    final idx = _items.indexWhere((i) => i.id == oldItem.id);
    if (idx != -1) {
      _items[idx] = oldItem; 
    } else {
      _items.insert(0, oldItem);
    }

    if (eventId != null) {
      _impactEvents.removeWhere((e) => e.id == eventId);
      _calculateStreakFromLocalEvents(); 
    }

    notifyListeners();
    await _saveLocalCache();

    try {
      await _ensureFamily();
      final itemPayload = _cleanJsonForDb(oldItem.toJson());
      await _supabase.from('inventory_items').upsert(itemPayload);
      if (eventId != null) {
        await _supabase.from('impact_events').delete().eq('id', eventId);
      }
    } catch (e) {
      await _queueOfflineAction('inventory_items', oldItem.toJson());
    }
  }

  Future<ImpactEvent?> recordImpactForAction(FoodItem item, String action, {double? overrideQty}) async {
    final qty = overrideQty ?? item.quantity;
    final factors = ImpactCalculator.calculate(item.name, item.category, qty, item.unit);

    double money = 0;
    double co2 = 0;
    ImpactType type;

    switch (action) {
      case 'eat':
        type = ImpactType.eaten;
        money = factors.pricePerKg;
        co2 = factors.co2PerKg;
        break;
      case 'pet':
        type = ImpactType.fedToPet;
        money = factors.pricePerKg;
        co2 = factors.co2PerKg;
        break;
      default:
        type = ImpactType.trash;
        money = 0;
        co2 = 0;
        break;
    }

    if (type != ImpactType.trash) {
      final event = ImpactEvent(
        id: const Uuid().v4(),
        date: DateTime.now(),
        type: type,
        quantity: qty,
        unit: item.unit,
        moneySaved: money,
        co2Saved: co2,
        itemName: item.name,
        itemCategory: item.category ?? 'general',
      );

      _impactEvents.insert(0, event);
      _updateStreakOnConsumed();
      _saveMeta();
      notifyListeners();
      await _saveLocalCache();

      if (_isLoggedIn) {
        try {
          await _ensureFamily();
          if (_currentFamilyId != null && _currentUserId != null) {
            final payload = _cleanJsonForDb(event.toJson(_currentFamilyId!, _currentUserId!));
            await _supabase.from('impact_events').insert(payload);
          }
        } catch (e) {
          if (_currentFamilyId != null && _currentUserId != null) {
            await _queueOfflineAction('impact_events', event.toJson(_currentFamilyId!, _currentUserId!));
          }
        }
      }
      return event;
    }
    return null;
  }

  // ================== Shopping List ==================

  List<ShoppingItem> getShoppingList() => List.unmodifiable(_activeShoppingList);

  Future<void> saveShoppingItem(ShoppingItem item) async {
    final idx = _activeShoppingList.indexWhere((i) => i.id == item.id);
    if (idx != -1) _activeShoppingList[idx] = item; else _activeShoppingList.add(item);
    notifyListeners();
    await _saveLocalCache();
    if (!_isLoggedIn) {
      await _queueOfflineAction('shopping_items', item.toLocalJson('', ''));
      return;
    }

    try {
      await _ensureFamily();
      if (_currentFamilyId == null) return;
      
      final payload = _cleanJsonForDb(item.toDbJson(_currentFamilyId!, _currentUserId ?? ''));
      await _supabase.from('shopping_items').upsert(payload).timeout(const Duration(seconds: 5));
    } catch (e) {
      await _queueOfflineAction('shopping_items', item.toLocalJson(_currentFamilyId ?? '', _currentUserId ?? ''));
    }
  }

  Future<void> toggleShoppingItemStatus(ShoppingItem item) async {
    item.isChecked = !item.isChecked;
    await saveShoppingItem(item); 
    if (item.isChecked) {
      await archiveShoppingItems([item]);
    } else {
      await removeRecentHistoryItem(item.name);
    }
  }

  Future<void> deleteShoppingItem(ShoppingItem item) async {
    _activeShoppingList.removeWhere((i) => i.id == item.id);
    notifyListeners();
    await _saveLocalCache();
    try {
      await _supabase.from('shopping_items').delete().eq('id', item.id);
      if (item.isChecked) await removeRecentHistoryItem(item.name);
    } catch (e) {
      debugPrint('Delete shopping error: $e');
    }
  }

  Future<void> checkoutShoppingItems(List<ShoppingItem> items) async {
    for (var item in items) {
      StorageLocation loc = StorageLocation.fridge;
      if (item.category == 'pantry') loc = StorageLocation.pantry;
      if (item.category == 'meat') loc = StorageLocation.freezer;
      if (item.category == 'pet') loc = StorageLocation.pantry;

      final newItem = FoodItem(
        id: const Uuid().v4(),
        name: item.name,
        category: item.category,
        quantity: 1,
        unit: 'pcs',
        purchasedDate: DateTime.now(),
        location: loc,
        source: 'shopping_list',
        ownerName: item.ownerName
      );
      await addItem(newItem);
      
      try {
        _supabase.from('shopping_items').delete().eq('id', item.id).then((_) {});
      } catch (_) {}
    }
    
    _activeShoppingList.removeWhere((i) => items.any((selected) => selected.id == i.id));
    notifyListeners();
    await _saveLocalCache();
  }

  // ================== History & Impact ==================

  List<ShoppingHistoryItem> get shoppingHistory {
    final list = List<ShoppingHistoryItem>.from(_shoppingHistory);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> archiveShoppingItems(List<ShoppingItem> items) async {
    final now = DateTime.now();
    for (var item in items) {
      final historyItem = ShoppingHistoryItem(id: const Uuid().v4(), name: item.name, category: item.category, date: now);
      _shoppingHistory.insert(0, historyItem);
      
      _ensureFamily().then((_) async {
        if (_currentFamilyId != null) {
          final payload = _cleanJsonForDb(historyItem.toJson(_currentFamilyId!, _currentUserId ?? ''));
          try {
             await _supabase.from('shopping_history').insert(payload);
          } catch (e) {
             await _queueOfflineAction('shopping_history', historyItem.toJson(_currentFamilyId!, _currentUserId ?? ''));
          }
        }
      });
    }
    notifyListeners();
    await _saveLocalCache();
  }

  Future<void> removeRecentHistoryItem(String name) async {
    final index = _shoppingHistory.indexWhere((e) => e.name == name);
    if (index != -1) {
      final item = _shoppingHistory[index];
      if (DateTime.now().difference(item.date).inMinutes < 60) {
        _shoppingHistory.removeAt(index);
        notifyListeners();
        await _saveLocalCache();

        try {
          await _supabase.from('shopping_history').delete().eq('id', item.id);
        } catch (e) { debugPrint('Remove history error: $e'); }
      }
    }
  }

  Future<void> clearHistory() async {
    _shoppingHistory.clear();
    notifyListeners();
    await _saveLocalCache();

    try {
      if (_currentFamilyId != null) {
        await _supabase.from('shopping_history').delete().eq('family_id', _currentFamilyId!);
      }
    } catch (e) { debugPrint('Clear history error: $e'); }
  }

  List<ImpactEvent> get impactEvents => List.unmodifiable(_impactEvents);
  int getSavedCount() => _impactEvents.where((e) => e.type != ImpactType.trash).length;
  int getWastedCount() => _impactEvents.where((e) => e.type == ImpactType.trash).length;

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

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fid = _currentFamilyId ?? '';
      final uid = _currentUserId ?? '';
      await prefs.setString('cache_inventory', jsonEncode(_items.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_shopping', jsonEncode(_activeShoppingList.map((e) => e.toLocalJson(fid, uid)).toList()));
      await prefs.setString('cache_history', jsonEncode(_shoppingHistory.map((e) => e.toJson(fid, uid)).toList()));
      await prefs.setString('cache_impact', jsonEncode(_impactEvents.map((e) => e.toJson(fid, uid)).toList()));
      await prefs.setString('pending_uploads', jsonEncode(_pendingUploads));
    } catch (_) {}
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s1 = prefs.getString('cache_inventory');
      if (s1 != null) {
        _items = (jsonDecode(s1) as List).map((e) {
          try { return FoodItem.fromJson(e); } catch(_) { return null; }
        }).whereType<FoodItem>().toList();
      }
      
      final s2 = prefs.getString('cache_shopping');
      if (s2 != null) {
        _activeShoppingList = (jsonDecode(s2) as List).map((e) {
          try { return ShoppingItem.fromJson(e); } catch(_) { return null; }
        }).whereType<ShoppingItem>().toList();
      }

      final s3 = prefs.getString('cache_history');
      if (s3 != null) _shoppingHistory = (jsonDecode(s3) as List).map((e) => ShoppingHistoryItem.fromJson(e)).toList();
      final s4 = prefs.getString('cache_impact');
      if (s4 != null) {
        _impactEvents = (jsonDecode(s4) as List).map((e) => ImpactEvent.fromJson(e)).toList();
        _calculateStreakFromLocalEvents();
      }
      
      final sPending = prefs.getString('pending_uploads');
      if (sPending != null) {
        _pendingUploads = List<Map<String, dynamic>>.from(jsonDecode(sPending));
      }

      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadLocalMeta() async {
    final prefs = await SharedPreferences.getInstance();
    hasShownPetWarning = prefs.getBool('petWarningShown') ?? false;
    _streakDays = prefs.getInt('streakDays') ?? 0;
    _isSharedUsage = prefs.getBool('is_shared_usage_v1') ?? true;
  }

  Future<void> _saveMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('petWarningShown', hasShownPetWarning);
    await prefs.setInt('streakDays', _streakDays);
  }

  void _calculateStreakFromLocalEvents() {
    if (_impactEvents.isEmpty) {
      _streakDays = 0;
      return;
    }

    final activeDates = _impactEvents.map((e) {
      return DateTime(e.date.year, e.date.month, e.date.day);
    }).toSet().toList();

    activeDates.sort((a, b) => b.compareTo(a));

    if (activeDates.isEmpty) {
      _streakDays = 0;
      return;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));
    
    final lastActive = activeDates.first;
    if (lastActive != todayDate && lastActive != yesterdayDate) {
      _streakDays = 0;
      return;
    }

    int streak = 1; 
    for (int i = 0; i < activeDates.length - 1; i++) {
      final current = activeDates[i];
      final previous = activeDates[i + 1];
      if (current.difference(previous).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    _streakDays = streak;
  }

  void _updateStreakOnConsumed() {
    _calculateStreakFromLocalEvents();
  }

  int getCurrentStreakDays() => _streakDays;

  Future<void> markPetWarningShown() async {
    hasShownPetWarning = true;
    await _saveMeta();
  }

  Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    try {
      await _ensureFamily();
      if (_currentFamilyId == null) return [];

      final res = await _supabase
          .from('family_members')
          .select('user_id, role, user_profiles(display_name, email)') 
          .eq('family_id', _currentFamilyId!);
      
      if ((res as List).isEmpty) return [];

      return (res as List).map((e) {
        final profile = e['user_profiles'];
        final profileMap = profile ?? {};
        return {
          'user_id': e['user_id'],
          'role': e['role'],
          'name': profileMap['display_name'] ?? profileMap['email'] ?? 'Member',
          'email': profileMap['email'] ?? '',
        };
      }).toList();

    } catch (e) {
      debugPrint('getFamilyMembers error -> $e');
      return [];
    }
  }

  Future<void> _refreshFamilyMemberCache() async {
    final members = await getFamilyMembers();
    _familyMemberCache = { for (var m in members) m['user_id'].toString() : m['name'].toString() };
  }

  Future<String> createInviteCode() async {
    if (_currentFamilyId == null) {
        await _initFamilySession();
    }
    if (_currentFamilyId == null) throw Exception("System Error: No Family Context. Please check your connection.");
    
    final code = (100000 + Random().nextInt(900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(hours: 48)).toIso8601String();

    await _supabase.from('family_invites').insert({
      'family_id': _currentFamilyId, 
      'inviter_id': _currentUserId, 
      'code': code,
      'expires_at': expiresAt,
    });
    return code;
  }

  Future<bool> joinFamily(String code) async {
    try {
      final invite = await _supabase.from('family_invites').select().eq('code', code).gt('expires_at', DateTime.now().toIso8601String()).maybeSingle();
      if (invite == null) return false;

      await _supabase.from('family_members').insert({
        'family_id': invite['family_id'],
        'user_id': _currentUserId, 
        'role': 'member'
      });
      
      final tempUid = _currentUserId;
      _resetState(); 
      _currentUserId = tempUid;
      _currentFamilyId = null;
      
      await _initFamilySession();
      await _fetchAllData();
      
      return true;
    } catch (e) {
      debugPrint('Join failed: $e');
      return false;
    }
  }

  Future<bool> leaveFamily() async {
    if (_currentUserId == null || _currentFamilyId == null) return false;
    try {
      await _supabase.from('family_members').delete().eq('family_id', _currentFamilyId!).eq('user_id', _currentUserId!);
      
      final tempUid = _currentUserId;
      _resetState();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_inventory');
      await prefs.remove('cache_shopping');
      await prefs.remove('cache_history');
      await prefs.remove('cache_impact');
      await prefs.remove('pending_uploads'); 
      
      _currentUserId = tempUid;
      await _createNewDefaultFamily(_currentUserId!);
      
      await _fetchAllData();
      return true;
    } catch (e) {
      debugPrint('Leave failed: $e');
      return false;
    }
  }
}
