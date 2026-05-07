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
import '../services/notification_service.dart';
import '../utils/app_locale.dart';
import '../utils/impact_calculator.dart';

// ================== Internal Models ==================
import '../models/shopping_item.dart';
import '../models/shopping_history_item.dart';
import '../models/impact_event.dart';
import '../models/meal_plan.dart';
// ================== Exports ==================
export '../models/shopping_item.dart';
export '../models/shopping_history_item.dart';
export '../models/impact_event.dart';

enum MigrationAction { join, leave }

enum MigrationPhase { idle, preparing, migrating, cleaning, completed, failed }

// ================== The Repository ==================

class InventoryRepository extends ChangeNotifier with WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _inventoryChannel;
  RealtimeChannel? _shoppingChannel;
  RealtimeChannel? _impactChannel;
  RealtimeChannel? _historyChannel;
  RealtimeChannel? _mealPlanChannel;
  StreamSubscription<AuthState>? _authSubscription;

  List<FoodItem> _items = [];
  List<ImpactEvent> _impactEvents = [];
  List<MealPlan> _mealPlans = [];
  final Map<String, MealPlan> _mealPlanIndex = {};
  List<ShoppingHistoryItem> _shoppingHistory = [];
  List<ShoppingItem> _activeShoppingList = [];
  DateTime? _lastActivityAt;
  DateTime? _lastSeenActivityAt;

  static const String _kShoppingClearDateKey = 'shopping_clear_date_v1';
  static const String _kExampleInventorySeedKey = 'seed_example_inventory_v1';
  static const String _kCategoryMemoryKey = 'category_memory_v1';
  Timer? _shoppingMidnightTimer;

  List<Map<String, dynamic>> _pendingUploads = [];

  bool hasShownPetWarning = false;
  int _streakDays = 0;
  Map<String, String> _categoryMemory = {};

  // Loading & Sync status
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool get hasPendingUploads => _pendingUploads.isNotEmpty;

  // Migration status
  MigrationPhase _migrationPhase = MigrationPhase.idle;
  MigrationAction? _migrationAction;
  String? _migrationMessage;
  String? _migrationError;
  int _migrationAttempt = 0;
  DateTime? _migrationUpdatedAt;

  MigrationPhase get migrationPhase => _migrationPhase;
  MigrationAction? get migrationAction => _migrationAction;
  String? get migrationMessage => _migrationMessage;
  String? get migrationError => _migrationError;
  int get migrationAttempt => _migrationAttempt;
  DateTime? get migrationUpdatedAt => _migrationUpdatedAt;

  // Shared usage (family) mode
  bool _isSharedUsage = true;
  bool get isSharedUsage => _isSharedUsage;

  String? _currentFamilyId;
  String? _currentFamilyName;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserEmail;

  Completer<void>? _sessionCompleter;
  bool get _isLoggedIn => _supabase.auth.currentUser != null;

  Map<String, String> _familyMemberCache = {};

  String get currentFamilyName => _currentFamilyName ?? 'My Home';
  String get currentUserName => _currentUserName ?? _currentUserEmail ?? 'User';

  InventoryRepository._() {
    _initAuthListener();
  }

  // ... (Migration methods unchanged) ...
  Future<void> _saveMigrationMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('migration_phase_v1', _migrationPhase.name);
      await prefs.setString(
          'migration_action_v1', _migrationAction?.name ?? '');
      await prefs.setString('migration_message_v1', _migrationMessage ?? '');
      await prefs.setString('migration_error_v1', _migrationError ?? '');
      await prefs.setInt('migration_attempt_v1', _migrationAttempt);
      await prefs.setString(
          'migration_updated_v1', _migrationUpdatedAt?.toIso8601String() ?? '');
    } catch (_) {}
  }

  Future<void> _clearMigrationMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('migration_phase_v1');
      await prefs.remove('migration_action_v1');
      await prefs.remove('migration_message_v1');
      await prefs.remove('migration_error_v1');
      await prefs.remove('migration_attempt_v1');
      await prefs.remove('migration_updated_v1');
    } catch (_) {}
  }

  void _setMigrationState(
    MigrationPhase phase, {
    MigrationAction? action,
    String? message,
    String? error,
    int? attempt,
  }) {
    _migrationPhase = phase;
    if (action != null) _migrationAction = action;
    if (message != null) _migrationMessage = message;
    _migrationError = error;
    if (attempt != null) _migrationAttempt = attempt;
    _migrationUpdatedAt = DateTime.now();
    notifyListeners();
    _saveMigrationMeta();
  }

  Future<T> _withRetry<T>(
    Future<T> Function() task, {
    int maxAttempts = 3,
    Duration baseDelay = const Duration(milliseconds: 400),
    String? stepLabel,
    MigrationAction? action,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _setMigrationState(
          MigrationPhase.migrating,
          action: action,
          message: stepLabel ?? 'Migrating...',
          attempt: attempt,
          error: null,
        );
        return await task();
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future.delayed(baseDelay * attempt);
        }
      }
    }
    throw lastError ?? Exception('Unknown migration error');
  }

  static Future<InventoryRepository> create() async {
    final repo = InventoryRepository._();
    await repo._loadLocalMeta();
    await repo._loadLocalCache();
    repo._initShoppingAutoClear();

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
    _shoppingMidnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runDailyShoppingClearIfNeeded();
      _scheduleShoppingMidnightClear();
      // On resume, do a quick sync check
      if (!_isLoading) _fetchAllData();
    }
  }

  Future<void> setSharedUsageMode(bool isShared) async {
    _isSharedUsage = isShared;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_shared_usage_v1', isShared);
  }

  Future<DateTime?> predictExpiryDate(
      String name, String location, DateTime purchasedDate) async {
    const String baseUrl = 'https://project-study-bsh.vercel.app';
    try {
      final locale = await AppLocale.fromPreferencesOrSystem();
      final response = await http.post(
        Uri.parse('$baseUrl/api/recipe'),
        headers: {
          'Content-Type': 'application/json',
          'Accept-Language': locale,
          'X-App-Locale': locale,
        },
        body: jsonEncode({
          'name': name,
          'location': location,
          'purchasedDate': purchasedDate.toIso8601String(),
          'locale': locale,
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
    if (_impactChannel != null) _supabase.removeChannel(_impactChannel!);
    if (_mealPlanChannel != null) _supabase.removeChannel(_mealPlanChannel!);
    if (_historyChannel != null) _supabase.removeChannel(_historyChannel!);
    _inventoryChannel = null;
    _shoppingChannel = null;
    _impactChannel = null;
    _mealPlanChannel = null;
    _historyChannel = null;
  }

  void _initShoppingAutoClear() {
    WidgetsBinding.instance.addObserver(this);
    _runDailyShoppingClearIfNeeded();
    _scheduleShoppingMidnightClear();
  }

  void _scheduleShoppingMidnightClear() {
    _shoppingMidnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);
    _shoppingMidnightTimer = Timer(delay, () async {
      await _runDailyShoppingClearIfNeeded();
      _scheduleShoppingMidnightClear();
    });
  }

  String _dateKey(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<void> _runDailyShoppingClearIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _dateKey(DateTime.now());
      final lastKey = prefs.getString(_kShoppingClearDateKey);
      if (lastKey == todayKey) return;

      await _clearCheckedShoppingItems();
      await prefs.setString(_kShoppingClearDateKey, todayKey);
    } catch (e) {
      debugPrint('Auto clear shopping error: $e');
    }
  }

  Future<void> _clearCheckedShoppingItems() async {
    final checkedItems = _activeShoppingList.where((i) => i.isChecked).toList();
    if (checkedItems.isEmpty) return;

    final checkedIds = checkedItems.map((i) => i.id).toSet();
    _activeShoppingList.removeWhere((i) => checkedIds.contains(i.id));
    _pendingUploads.removeWhere((e) {
      final table = e['meta_table'] ?? 'inventory_items';
      final id = e['id']?.toString();
      return table == 'shopping_items' && id != null && checkedIds.contains(id);
    });
    notifyListeners();
    await _saveLocalCache();

    if (!_isLoggedIn) return;
    try {
      await _ensureFamily();
      if (_currentFamilyId == null) return;
      await _supabase
          .from('shopping_items')
          .delete()
          .inFilter('id', checkedIds.toList());
    } catch (e) {
      debugPrint('Auto clear shopping server delete error: $e');
    }
  }

  void _initAuthListener() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _sessionCompleter = null;
        await refreshAll(force: true);
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
      _mealPlans = [];
      _mealPlanIndex.clear();
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
        final profile = await _supabase
            .from('user_profiles')
            .select('display_name')
            .eq('id', user.id)
            .maybeSingle();
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
      debugPrint('Session init error: $e');
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
      debugPrint('Failed to create default family: $e');
    }
  }

  // >>>>>> SMART SYNC LOGIC STARTS HERE <<<<<<

  Future<void> _fetchAllData() async {
    if (_isLoading) return; // Prevent double fetch
    _isLoading = true;
    notifyListeners();

    await _ensureFamily();
    if (_currentFamilyId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    await _processPendingQueue();

    try {
      _refreshFamilyMemberCache()
          .catchError((e) => debugPrint("Member cache error: $e"));

      await Future.wait([
        _syncInventory(),
        _syncShopping(),
        // Simple fetches for smaller/historical tables
        _simpleFetchHistory(),
        _simpleFetchImpact(),
        _simpleFetchMealPlans(),
      ]);

      _updateLatestActivityFromData();
      _calculateStreakFromLocalEvents();
      await _saveLocalCache();
    } catch (e) {
      debugPrint('Fetch data error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Incremental Sync for Inventory ---
  Future<void> _syncInventory() async {
    try {
      // 1. Fetch Manifest (ID + UpdatedAt)
      final manifest = await _supabase
          .from('inventory_items')
          .select('id, updated_at')
          .eq('family_id', _currentFamilyId!);

      final List<dynamic> manifestList = manifest as List<dynamic>;
      final serverMap = {
        for (var m in manifestList)
          m['id'].toString():
              DateTime.tryParse(m['updated_at']?.toString() ?? '')
      };

      final pendingIds = _pendingUploads
          .where((e) =>
              e['meta_table'] == 'inventory_items' || e['meta_table'] == null)
          .map((e) => e['id'].toString())
          .toSet();

      final idsToFetch = <String>[];
      final idsToDelete = <String>[];
      final localMap = {for (var i in _items) i.id: i};

      // 2. Identify Changes
      for (var entry in serverMap.entries) {
        final serverId = entry.key;
        final serverTime = entry.value;
        final localItem = localMap[serverId];

        // Fetch if: New item OR Server is newer than Local
        if (localItem == null) {
          idsToFetch.add(serverId);
        } else {
          // If local timestamp is null, assume we need update.
          // If server timestamp is newer, we need update.
          // Note: If pending upload exists for this item, DON'T fetch (prefer local edits)
          if (!pendingIds.contains(serverId)) {
            if (serverTime != null &&
                (localItem.updatedAt == null ||
                    serverTime.isAfter(localItem.updatedAt!))) {
              idsToFetch.add(serverId);
            }
          }
        }
      }

      // 3. Identify Deletions (In Local but not in Server, and not pending creation)
      for (var localItem in _items) {
        if (!serverMap.containsKey(localItem.id) &&
            !pendingIds.contains(localItem.id)) {
          // Double check it's not a "example" item
          if (localItem.source != 'example') {
            idsToDelete.add(localItem.id);
          }
        }
      }

      // 4. Execute Updates
      if (idsToDelete.isNotEmpty) {
        _items.removeWhere((i) => idsToDelete.contains(i.id));
      }

      if (idsToFetch.isNotEmpty) {
        // Fetch in batches if too many
        final chunked = _chunkList(idsToFetch, 50);
        for (var chunk in chunked) {
          final response = await _supabase
              .from('inventory_items')
              .select('*, user_profiles(display_name, email)')
              .inFilter('id', chunk);

          final newItems = (response as List)
              .map((e) {
                try {
                  return FoodItem.fromJson(_injectFallbackName(e));
                } catch (_) {
                  return null;
                }
              })
              .whereType<FoodItem>()
              .toList();

          for (var newItem in newItems) {
            final idx = _items.indexWhere((i) => i.id == newItem.id);
            if (idx != -1) {
              _items[idx] = newItem;
            } else {
              _items.add(newItem);
            }
          }
        }
      }

      // 5. Cleanup and Sort
      _items.sort((a, b) => b.purchasedDate.compareTo(a.purchasedDate));
      await _maybeSeedExampleInventoryItem(setFlag: true);
    } catch (e) {
      debugPrint("Sync Inventory Error: $e");
    }
  }

  // --- Incremental Sync for Shopping ---
  Future<void> _syncShopping() async {
    try {
      final manifest = await _supabase
          .from('shopping_items')
          .select('id, updated_at')
          .eq('family_id', _currentFamilyId!);

      final List<dynamic> manifestList = manifest as List<dynamic>;
      final serverMap = {
        for (var m in manifestList)
          m['id'].toString():
              DateTime.tryParse(m['updated_at']?.toString() ?? '')
      };

      final pendingIds = _pendingUploads
          .where((e) => e['meta_table'] == 'shopping_items')
          .map((e) => e['id'].toString())
          .toSet();

      final idsToFetch = <String>[];
      final idsToDelete = <String>[];
      final localMap = {for (var i in _activeShoppingList) i.id: i};

      for (var entry in serverMap.entries) {
        final serverId = entry.key;
        final serverTime = entry.value;
        final localItem = localMap[serverId];

        if (localItem == null) {
          idsToFetch.add(serverId);
        } else {
          if (!pendingIds.contains(serverId)) {
            if (serverTime != null &&
                (localItem.updatedAt == null ||
                    serverTime.isAfter(localItem.updatedAt!))) {
              idsToFetch.add(serverId);
            }
          }
        }
      }

      for (var localItem in _activeShoppingList) {
        if (!serverMap.containsKey(localItem.id) &&
            !pendingIds.contains(localItem.id)) {
          idsToDelete.add(localItem.id);
        }
      }

      if (idsToDelete.isNotEmpty) {
        _activeShoppingList.removeWhere((i) => idsToDelete.contains(i.id));
      }

      if (idsToFetch.isNotEmpty) {
        final chunked = _chunkList(idsToFetch, 50);
        for (var chunk in chunked) {
          final response = await _supabase
              .from('shopping_items')
              .select('*, user_profiles(display_name, email)')
              .inFilter('id', chunk);

          final newItems = (response as List)
              .map((e) {
                try {
                  return ShoppingItem.fromJson(_injectFallbackName(e));
                } catch (_) {
                  return null;
                }
              })
              .whereType<ShoppingItem>()
              .toList();

          for (var newItem in newItems) {
            final idx =
                _activeShoppingList.indexWhere((i) => i.id == newItem.id);
            if (idx != -1) {
              _activeShoppingList[idx] = newItem;
            } else {
              _activeShoppingList.add(newItem);
            }
          }
        }
      }
      _activeShoppingList
          .sort((a, b) => (a.isChecked ? 1 : 0).compareTo(b.isChecked ? 1 : 0));
    } catch (e) {
      debugPrint("Sync Shopping Error: $e");
    }
  }

  // Helpers for simple tables
  Future<void> _simpleFetchHistory() async {
    try {
      // Since history is append-only mostly, we can just fetch last 50
      final response = await _supabase
          .from('shopping_history')
          .select()
          .eq('family_id', _currentFamilyId!)
          .order('added_date', ascending: false)
          .limit(100);
      _shoppingHistory = (response as List)
          .map((e) => ShoppingHistoryItem.fromJson(e))
          .toList();
    } catch (_) {}
  }

  Future<void> _simpleFetchImpact() async {
    try {
      final response = await _supabase
          .from('impact_events')
          .select()
          .eq('family_id', _currentFamilyId!)
          .order('created_at', ascending: false);
      _impactEvents =
          (response as List).map((e) => ImpactEvent.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<void> _simpleFetchMealPlans() async {
    try {
      final response = await _supabase
          .from('meal_plans')
          .select()
          .eq('family_id', _currentFamilyId!);
      _mergeMealPlans(
          (response as List).map((e) => MealPlan.fromJson(e)).toList());
    } catch (_) {}
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, min(i + chunkSize, list.length)));
    }
    return chunks;
  }

  // >>>>>> SMART SYNC LOGIC ENDS <<<<<<

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

    _inventoryChannel = _supabase
        .channel('public:inventory:$_currentFamilyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_id',
              value: _currentFamilyId!),
          callback: (payload) => _handleInventoryRealtime(payload),
        )
        .subscribe();

    _shoppingChannel = _supabase
        .channel('public:shopping:$_currentFamilyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_items',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_id',
              value: _currentFamilyId!),
          callback: (payload) => _handleShoppingRealtime(payload),
        )
        .subscribe();

    _historyChannel = _supabase
        .channel('public:shopping_history:$_currentFamilyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_history',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_id',
              value: _currentFamilyId!),
          callback: (payload) => _handleShoppingHistoryRealtime(payload),
        )
        .subscribe();

    _impactChannel = _supabase
        .channel('public:impact:$_currentFamilyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'impact_events',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_id',
              value: _currentFamilyId!),
          callback: (payload) => _handleImpactRealtime(payload),
        )
        .subscribe();

    _mealPlanChannel = _supabase
        .channel('public:meal_plans:$_currentFamilyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meal_plans',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_id',
              value: _currentFamilyId!),
          callback: (payload) => _handleMealPlanRealtime(payload),
        )
        .subscribe();
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
      if (idx != -1) {
        final existingItem = _items[idx];
        final newItem = FoodItem.fromJson(_injectFallbackName(newRec));

        // 智能合并：如果实时推送的数据中丢失了 ownerName（通常是因为 Realtime 不带 join 数据），
        // 则保留本地已有的 ownerName。
        final mergedItem = newItem.copyWith(
          ownerName:
              (newItem.ownerName == null || newItem.ownerName == 'Family')
                  ? existingItem.ownerName // 如果新名字无效，使用旧名字
                  : newItem.ownerName, // 否则使用新名字
        );

        _items[idx] = mergedItem;
      }
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      _items.removeWhere((i) => i.id == oldRec['id']);
    }
    _saveLocalCache();
    notifyListeners();
  }

  void _handleImpactRealtime(PostgresChangePayload payload) {
    if (_currentFamilyId == null) return;
    final newRec = payload.newRecord;
    final oldRec = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.insert) {
      if (!_impactEvents.any((e) => e.id == newRec['id'])) {
        _impactEvents.insert(0, ImpactEvent.fromJson(newRec));
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final idx = _impactEvents.indexWhere((e) => e.id == newRec['id']);
      if (idx != -1) _impactEvents[idx] = ImpactEvent.fromJson(newRec);
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      _impactEvents.removeWhere((e) => e.id == oldRec['id']);
    }
    _updateLatestActivityFromData();
    _saveLocalCache();
    notifyListeners();
  }

  void _handleShoppingHistoryRealtime(PostgresChangePayload payload) {
    if (_currentFamilyId == null) return;
    final newRec = payload.newRecord;
    final oldRec = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.insert) {
      if (!_shoppingHistory.any((e) => e.id == newRec['id'])) {
        _shoppingHistory.insert(0, ShoppingHistoryItem.fromJson(newRec));
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final idx = _shoppingHistory.indexWhere((e) => e.id == newRec['id']);
      if (idx != -1)
        _shoppingHistory[idx] = ShoppingHistoryItem.fromJson(newRec);
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      _shoppingHistory.removeWhere((e) => e.id == oldRec['id']);
    }
    _updateLatestActivityFromData();
    _saveLocalCache();
    notifyListeners();
  }

  void _handleShoppingRealtime(PostgresChangePayload payload) {
    if (_currentFamilyId == null) return;
    final newRec = payload.newRecord;
    final oldRec = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.insert) {
      if (!_activeShoppingList.any((i) => i.id == newRec['id'])) {
        _activeShoppingList
            .add(ShoppingItem.fromJson(_injectFallbackName(newRec)));
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final idx = _activeShoppingList.indexWhere((i) => i.id == newRec['id']);
      if (idx != -1)
        _activeShoppingList[idx] =
            ShoppingItem.fromJson(_injectFallbackName(newRec));
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      _activeShoppingList.removeWhere((i) => i.id == oldRec['id']);
    }
    _saveLocalCache();
    notifyListeners();
  }

  void _handleMealPlanRealtime(PostgresChangePayload payload) {
    if (_currentFamilyId == null) return;
    final newRec = payload.newRecord;
    final oldRec = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.insert ||
        payload.eventType == PostgresChangeEvent.update) {
      final plan = MealPlan.fromJson(newRec);
      _upsertMealPlanLocal(plan, notify: false);
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final id = oldRec['id']?.toString();
      if (id != null) {
        _mealPlans.removeWhere((e) => e.id == id);
        _mealPlanIndex.removeWhere((_, value) => value.id == id);
      }
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
    } else {
      name = 'Family';
    }

    final newMap = Map<String, dynamic>.from(json);
    newMap['user_profiles'] = {'display_name': name};
    return newMap;
  }

  Map<String, dynamic> _cleanJsonForDb(Map<String, dynamic> rawJson,
      {String? tableName}) {
    final json = Map<String, dynamic>.from(rawJson);
    json.remove('user_profiles');
    json.remove('owner_name');
    json.remove('ownerName');
    json.remove('display_name');
    json.remove('meta_table');
    json.remove('meta_delete');

    if (_currentFamilyId != null) json['family_id'] = _currentFamilyId;

    // Only set user_id when missing and current user is available.
    if (!json.containsKey('user_id') && _currentUserId != null) {
      json['user_id'] = _currentUserId;
    }

    // Ensure updated_at is refreshed on write, BUT only for tables that support it.
    // impact_events and shopping_history usually don't have updated_at.
    if (tableName != 'impact_events' && tableName != 'shopping_history') {
      json['updated_at'] = DateTime.now().toUtc().toIso8601String();
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

        if (itemJson['meta_delete'] == true) {
          final id = itemJson['id']?.toString();
          if (id == null) continue;
          await _supabase
              .from(tableName)
              .delete()
              .eq('id', id)
              .eq('family_id', _currentFamilyId!)
              .timeout(const Duration(seconds: 5));
          successful.add(itemWithMeta);
        } else {
          itemJson['family_id'] = _currentFamilyId;
          if (itemJson['user_id'] == null ||
              itemJson['user_id'].toString().isEmpty) {
            itemJson['user_id'] = _currentUserId;
          }

          final payload = _cleanJsonForDb(itemJson, tableName: tableName);
          await _supabase
              .from(tableName)
              .upsert(payload)
              .timeout(const Duration(seconds: 5));
          successful.add(itemWithMeta);
        }
      } catch (e) {
        debugPrint("???Sync failed for item: $e");
      }
    }
    if (successful.isNotEmpty) {
      _pendingUploads.removeWhere((pending) => successful.contains(pending));
      await _saveLocalCache();
      notifyListeners();
    }
  }

  Future<void> _queueOfflineAction(
      String tableName, Map<String, dynamic> rawJson) async {
    final payload = _cleanJsonForDb(rawJson, tableName: tableName);
    if (payload['user_id'] == null || payload['user_id'].toString().isEmpty) {
      payload.remove('user_id');
    }
    payload['meta_table'] = tableName;
    // Update updated_at for offline too so it sorts correctly locally
    if (tableName != 'impact_events' && tableName != 'shopping_history') {
      payload['updated_at'] = DateTime.now().toUtc().toIso8601String();
    }

    final idx = _pendingUploads.indexWhere((e) => e['id'] == payload['id']);
    if (idx != -1) {
      _pendingUploads[idx] = payload;
    } else {
      _pendingUploads.add(payload);
    }
    await _saveLocalCache();
    notifyListeners();
  }

  Future<void> _queueOfflineDelete(String tableName, String id) async {
    final payload = <String, dynamic>{
      'id': id,
      'meta_table': tableName,
      'meta_delete': true,
    };
    final idx = _pendingUploads
        .indexWhere((e) => e['id'] == id && e['meta_table'] == tableName);
    if (idx != -1) {
      _pendingUploads[idx] = payload;
    } else {
      _pendingUploads.add(payload);
    }
    await _saveLocalCache();
    notifyListeners();
  }

  List<FoodItem> getActiveItems() =>
      _items.where((i) => i.status == FoodStatus.good).toList();
  List<FoodItem> getExpiringItems(int days) =>
      getActiveItems().where((i) => i.daysToExpiry <= days).toList();

  String _mealKey(DateTime date, String slot) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d-$slot';
  }

  void _rebuildMealIndex() {
    _mealPlanIndex.clear();
    for (final plan in _mealPlans) {
      _mealPlanIndex[_mealKey(plan.planDate, plan.slot)] = plan;
    }
  }

  void _mergeMealPlans(List<MealPlan> serverPlans) {
    final pendingDeletes = _pendingUploads
        .where(
            (e) => e['meta_table'] == 'meal_plans' && e['meta_delete'] == true)
        .map((e) => e['id']?.toString())
        .whereType<String>()
        .toSet();

    final pendingUpserts = _pendingUploads
        .where(
            (e) => e['meta_table'] == 'meal_plans' && e['meta_delete'] != true)
        .map((e) {
          try {
            return MealPlan.fromJson(e);
          } catch (_) {
            return null;
          }
        })
        .whereType<MealPlan>()
        .toList();

    final merged = <MealPlan>[];
    for (final plan in serverPlans) {
      if (pendingDeletes.contains(plan.id)) continue;
      merged.add(plan);
    }
    for (final local in pendingUpserts) {
      final idx = merged.indexWhere((p) => p.id == local.id);
      if (idx == -1) {
        merged.add(local);
      } else {
        merged[idx] = local.updatedAt.isAfter(merged[idx].updatedAt)
            ? local
            : merged[idx];
      }
    }
    _mealPlans = merged;
    _rebuildMealIndex();
  }

  void _upsertMealPlanLocal(MealPlan plan, {bool notify = true}) {
    final idx = _mealPlans.indexWhere((e) => e.id == plan.id);
    if (idx == -1) {
      _mealPlans.add(plan);
    } else {
      _mealPlans[idx] = plan;
    }
    _mealPlanIndex[_mealKey(plan.planDate, plan.slot)] = plan;
    if (notify) {
      _saveLocalCache();
      notifyListeners();
    }
  }

  Future<void> upsertMealPlan({
    required DateTime date,
    required String slot,
    required String mealName,
    String? recipeName,
    Set<String> itemIds = const {},
    List<String> missingItems = const [],
  }) async {
    final existing = getMealPlan(date, slot);
    final id = existing?.id ?? const Uuid().v4();
    final plan = MealPlan(
      id: id,
      familyId: _currentFamilyId,
      userId: _currentUserId ?? '',
      planDate: DateTime(date.year, date.month, date.day),
      slot: slot,
      mealName: mealName,
      recipeName: recipeName,
      itemIds: itemIds,
      missingItems: missingItems,
      updatedAt: DateTime.now(),
    );

    _upsertMealPlanLocal(plan);

    if (!_isLoggedIn) {
      await _queueOfflineAction('meal_plans', plan.toLocalJson());
      return;
    }

    try {
      await _ensureFamily();
      if (_currentFamilyId == null)
        throw Exception("Cannot sync: No family context");
      final payload = _cleanJsonForDb(plan.toDbJson(), tableName: 'meal_plans');
      await _supabase
          .from('meal_plans')
          .upsert(payload)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      await _queueOfflineAction('meal_plans', plan.toLocalJson());
    }
  }

  Future<void> deleteMealPlan(DateTime date, String slot) async {
    final existing = getMealPlan(date, slot);
    if (existing == null) return;
    _mealPlans.removeWhere((e) => e.id == existing.id);
    _mealPlanIndex.remove(_mealKey(date, slot));
    notifyListeners();
    await _saveLocalCache();

    if (!_isLoggedIn) {
      await _queueOfflineDelete('meal_plans', existing.id);
      return;
    }

    try {
      await _ensureFamily();
      if (_currentFamilyId == null)
        throw Exception("Cannot sync: No family context");
      await _supabase
          .from('meal_plans')
          .delete()
          .eq('id', existing.id)
          .eq('family_id', _currentFamilyId!)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      await _queueOfflineDelete('meal_plans', existing.id);
    }
  }

  Future<void> removeExampleInventoryItems() async {
    final before = _items.length;
    _items.removeWhere((i) => i.source == 'example');
    if (_items.length == before) return;
    notifyListeners();
    await _saveLocalCache();
  }

  Future<void> refreshAll({bool force = false}) async {
    if (force) {
      _resetState(keepLocal: false);
    }
    await _initFamilySession();
    await _fetchAllData();
  }

  Future<void> addItem(FoodItem item) async {
    final effectiveOwner = currentUserName;
    // Set updatedAt initially
    final optimisticItem =
        item.copyWith(ownerName: effectiveOwner, updatedAt: DateTime.now());
    _items.insert(0, optimisticItem);
    notifyListeners();
    await _saveLocalCache();
    if (!_isLoggedIn) {
      await _queueOfflineAction('inventory_items', optimisticItem.toJson());
      return;
    }

    try {
      await _ensureFamily();
      if (_currentFamilyId == null)
        throw Exception("Cannot sync: No family context");

      var payload = optimisticItem.toJson();
      if (!_isSharedUsage) {
        payload['user_id'] = _currentUserId;
      }
      payload = _cleanJsonForDb(payload, tableName: 'inventory_items');

      await _supabase
          .from('inventory_items')
          .insert(payload)
          .timeout(const Duration(seconds: 5));
      await _checkAutoRefill(item);
    } catch (e) {
      await _queueOfflineAction('inventory_items', optimisticItem.toJson());
    }
  }

  Future<void> updateItem(FoodItem item) async {
    final updatedItem = item.copyWith(updatedAt: DateTime.now());
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) _items[idx] = updatedItem;
    notifyListeners();
    await _saveLocalCache();
    if (!_isLoggedIn) {
      await _queueOfflineAction('inventory_items', updatedItem.toJson());
      return;
    }

    try {
      await _ensureFamily();
      final payload =
          _cleanJsonForDb(updatedItem.toJson(), tableName: 'inventory_items');
      payload.remove('created_at');
      payload.remove('user_id');

      await _supabase
          .from('inventory_items')
          .update(payload)
          .eq('id', item.id)
          .timeout(const Duration(seconds: 5));
      await _checkAutoRefill(item);
    } catch (e) {
      await _queueOfflineAction('inventory_items', updatedItem.toJson());
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
      _items[index] = _items[index]
          .copyWith(ownerName: memberName, updatedAt: DateTime.now());
      notifyListeners();
      await _saveLocalCache();
    }

    try {
      await _ensureFamily();
      if (targetUserId != null) {
        await _supabase.from('inventory_items').update({
          'user_id': targetUserId,
          'updated_at': DateTime.now().toUtc().toIso8601String()
        }).eq('id', itemId);
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
      await _supabase
          .from('inventory_items')
          .delete()
          .eq('id', id)
          .timeout(const Duration(seconds: 5));
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

  Future<void> useItemWithImpact(
      FoodItem item, String action, double usedQty) async {
    if (usedQty <= 0) return;

    // Clamp and normalize to avoid float precision issues.
    double clamped = usedQty.clamp(0, item.quantity).toDouble();
    clamped = double.parse(clamped.toStringAsFixed(2));

    await recordImpactForAction(item, action, overrideQty: clamped);

    double remaining = item.quantity - clamped;
    remaining = double.parse(remaining.toStringAsFixed(2));

    if (remaining <= 0.0001) {
      await updateStatus(item.id, FoodStatus.consumed);
    } else {
      await updateItem(item.copyWith(quantity: remaining));
    }
  }

  Future<void> undoConsume(FoodItem oldItem, String? eventId) async {
    final restoredItem = oldItem.copyWith(updatedAt: DateTime.now());
    final idx = _items.indexWhere((i) => i.id == oldItem.id);
    if (idx != -1) {
      _items[idx] = restoredItem;
    } else {
      _items.insert(0, restoredItem);
    }

    if (eventId != null) {
      _impactEvents.removeWhere((e) => e.id == eventId);
      _calculateStreakFromLocalEvents();
    }

    notifyListeners();
    await _saveLocalCache();

    try {
      await _ensureFamily();
      final itemPayload =
          _cleanJsonForDb(restoredItem.toJson(), tableName: 'inventory_items');
      await _supabase.from('inventory_items').upsert(itemPayload);
      if (eventId != null) {
        await _supabase.from('impact_events').delete().eq('id', eventId);
      }
    } catch (e) {
      await _queueOfflineAction('inventory_items', restoredItem.toJson());
    }
  }

  Future<ImpactEvent?> recordImpactForAction(FoodItem item, String action,
      {double? overrideQty}) async {
    final qty = overrideQty ?? item.quantity;
    final factors =
        ImpactCalculator.calculate(item.name, item.category, qty, item.unit);

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
        userId: _currentUserId,
      );

      _impactEvents.insert(0, event);
      _updateLatestActivityFromData();
      _updateStreakOnConsumed();
      _saveMeta();
      notifyListeners();
      await _saveLocalCache();

      if (_isLoggedIn) {
        try {
          await _ensureFamily();
          if (_currentFamilyId != null && _currentUserId != null) {
            final payload = _cleanJsonForDb(
                event.toJson(_currentFamilyId!, _currentUserId!),
                tableName: 'impact_events');
            await _supabase.from('impact_events').insert(payload);
          }
        } catch (e) {
          if (_currentFamilyId != null && _currentUserId != null) {
            await _queueOfflineAction('impact_events',
                event.toJson(_currentFamilyId!, _currentUserId!));
          }
        }
      }
      return event;
    }
    return null;
  }

  // ================== Shopping List ==================

  List<ShoppingItem> getShoppingList() =>
      List.unmodifiable(_activeShoppingList);

  bool get hasUnreadActivity {
    if (_lastActivityAt == null) return false;
    if (_lastSeenActivityAt == null) return true;
    return _lastActivityAt!.isAfter(_lastSeenActivityAt!);
  }

  Future<void> markActivitySeen() async {
    _lastSeenActivityAt = _lastActivityAt ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_seen_activity_v1', _lastSeenActivityAt!.toIso8601String());
    notifyListeners();
  }

  String? resolveUserNameById(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    if (_currentUserId != null && userId == _currentUserId)
      return currentUserName;
    return _familyMemberCache[userId] ?? 'Family';
  }

  String? getBuyerNameForItemId(String itemId) {
    final match = _shoppingHistory.firstWhere(
      (e) => e.shoppingItemId == itemId,
      orElse: () => ShoppingHistoryItem(
          id: '', name: '', category: '', date: DateTime.now()),
    );
    if (match.id.isEmpty) return null;
    return resolveUserNameById(match.userId);
  }

  void _updateLatestActivityFromData() {
    DateTime? latest;
    if (_shoppingHistory.isNotEmpty) {
      latest = _shoppingHistory
          .map((e) => e.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }
    if (_impactEvents.isNotEmpty) {
      final impactLatest = _impactEvents
          .map((e) => e.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      if (latest == null || impactLatest.isAfter(latest)) latest = impactLatest;
    }
    _lastActivityAt = latest;
  }

  Future<void> saveShoppingItem(ShoppingItem item) async {
    final createdAt = item.createdAt ?? DateTime.now();
    final ownerName =
        (item.ownerName != null && item.ownerName!.trim().isNotEmpty)
            ? item.ownerName
            : ((_currentUserId != null && _currentUserId!.isNotEmpty)
                ? currentUserName
                : null);
    final userId = (item.userId != null && item.userId!.trim().isNotEmpty)
        ? item.userId
        : _currentUserId;
    final updatedItem = ShoppingItem(
        id: item.id,
        name: item.name,
        category: item.category,
        isChecked: item.isChecked,
        ownerName: ownerName,
        userId: userId,
        note: item.note,
        createdAt: createdAt,
        updatedAt: DateTime.now());

    final idx = _activeShoppingList.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      _activeShoppingList[idx] = updatedItem;
    } else {
      _activeShoppingList.add(updatedItem);
    }
    notifyListeners();
    await _saveLocalCache();
    if (!_isLoggedIn) {
      await _queueOfflineAction(
          'shopping_items', updatedItem.toLocalJson('', ''));
      return;
    }

    try {
      await _ensureFamily();
      if (_currentFamilyId == null) return;

      final payload = _cleanJsonForDb(
          updatedItem.toDbJson(_currentFamilyId!, _currentUserId ?? ''),
          tableName: 'shopping_items');
      await _supabase
          .from('shopping_items')
          .upsert(payload)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      await _queueOfflineAction(
          'shopping_items',
          updatedItem.toLocalJson(
              _currentFamilyId ?? '', _currentUserId ?? ''));
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

  Future<void> updateItemNote(FoodItem item, String? note) async {
    final updated = item.copyWith(
        note: (note != null && note.trim().isEmpty) ? null : note);
    await updateItem(updated);
  }

  Future<void> updateShoppingItemNote(ShoppingItem item, String? note) async {
    final updated = ShoppingItem(
      id: item.id,
      name: item.name,
      category: item.category,
      isChecked: item.isChecked,
      ownerName: item.ownerName,
      userId: item.userId,
      note: (note != null && note.trim().isEmpty) ? null : note,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
    );
    await saveShoppingItem(updated);
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
        ownerName: item.ownerName,
        updatedAt: DateTime.now(),
      );
      await addItem(newItem);

      try {
        _supabase
            .from('shopping_items')
            .delete()
            .eq('id', item.id)
            .then((_) {});
      } catch (_) {}
    }

    _activeShoppingList
        .removeWhere((i) => items.any((selected) => selected.id == i.id));
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
      final historyItem = ShoppingHistoryItem(
        id: const Uuid().v4(),
        name: item.name,
        category: item.category,
        date: now,
        userId: _currentUserId,
        shoppingItemId: item.id,
      );
      _shoppingHistory.insert(0, historyItem);
      _updateLatestActivityFromData();

      _ensureFamily().then((_) async {
        if (_currentFamilyId != null) {
          final payload = _cleanJsonForDb(
              historyItem.toJson(_currentFamilyId!, _currentUserId ?? ''),
              tableName: 'shopping_history');
          try {
            await _supabase.from('shopping_history').insert(payload);
          } catch (e) {
            await _queueOfflineAction('shopping_history',
                historyItem.toJson(_currentFamilyId!, _currentUserId ?? ''));
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
        } catch (e) {
          debugPrint('Remove history error: $e');
        }
      }
    }
  }

  Future<void> clearHistory() async {
    _shoppingHistory.clear();
    notifyListeners();
    await _saveLocalCache();

    try {
      if (_currentFamilyId != null) {
        await _supabase
            .from('shopping_history')
            .delete()
            .eq('family_id', _currentFamilyId!);
      }
    } catch (e) {
      debugPrint('Clear history error: $e');
    }
  }

  List<ImpactEvent> get impactEvents => List.unmodifiable(_impactEvents);
  List<MealPlan> get mealPlans => List.unmodifiable(_mealPlans);

  MealPlan? getMealPlan(DateTime date, String slot) {
    return _mealPlanIndex[_mealKey(date, slot)];
  }

  List<MealPlan> getMealPlansForRange(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return _mealPlans.where((plan) {
      final d =
          DateTime(plan.planDate.year, plan.planDate.month, plan.planDate.day);
      return !d.isBefore(startDate) && d.isBefore(endDate);
    }).toList();
  }

  int getSavedCount() =>
      _impactEvents.where((e) => e.type != ImpactType.trash).length;
  int getWastedCount() =>
      _impactEvents.where((e) => e.type == ImpactType.trash).length;

  Future<void> _checkAutoRefill(FoodItem item) async {
    if (item.minQuantity == null) return;
    if (item.quantity <= item.minQuantity!) {
      final isPending = _activeShoppingList.any((s) =>
          s.name.toLowerCase() == item.name.toLowerCase() && !s.isChecked);
      if (!isPending) {
        final newItem = ShoppingItem(
            id: const Uuid().v4(),
            name: item.name,
            category: item.category ?? 'general',
            updatedAt: DateTime.now());
        await saveShoppingItem(newItem);
      }
    }
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fid = _currentFamilyId ?? '';
      final uid = _currentUserId ?? '';
      await prefs.setString('cache_inventory',
          jsonEncode(_items.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'cache_shopping',
          jsonEncode(_activeShoppingList
              .map((e) => e.toLocalJson(fid, uid))
              .toList()));
      await prefs.setString('cache_history',
          jsonEncode(_shoppingHistory.map((e) => e.toJson(fid, uid)).toList()));
      await prefs.setString('cache_impact',
          jsonEncode(_impactEvents.map((e) => e.toJson(fid, uid)).toList()));
      await prefs.setString('cache_meal_plans',
          jsonEncode(_mealPlans.map((e) => e.toLocalJson()).toList()));
      await prefs.setString('pending_uploads', jsonEncode(_pendingUploads));

      final threeDayEnabled =
          prefs.getBool(kThreeDayReminderEnabledPrefKey) ?? true;
      if (threeDayEnabled) {
        await NotificationService().scheduleThreeDayExpiryReminders(
          items: getActiveItems(),
        );
      } else {
        await NotificationService().cancelThreeDayExpiryReminders();
      }
    } catch (_) {}
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s1 = prefs.getString('cache_inventory');
      if (s1 != null) {
        _items = (jsonDecode(s1) as List)
            .map((e) {
              try {
                return FoodItem.fromJson(e);
              } catch (_) {
                return null;
              }
            })
            .whereType<FoodItem>()
            .toList();
      }

      final s2 = prefs.getString('cache_shopping');
      if (s2 != null) {
        _activeShoppingList = (jsonDecode(s2) as List)
            .map((e) {
              try {
                return ShoppingItem.fromJson(e);
              } catch (_) {
                return null;
              }
            })
            .whereType<ShoppingItem>()
            .toList();
      }

      final s3 = prefs.getString('cache_history');
      if (s3 != null)
        _shoppingHistory = (jsonDecode(s3) as List)
            .map((e) => ShoppingHistoryItem.fromJson(e))
            .toList();
      final s4 = prefs.getString('cache_impact');
      if (s4 != null) {
        _impactEvents = (jsonDecode(s4) as List)
            .map((e) => ImpactEvent.fromJson(e))
            .toList();
        _calculateStreakFromLocalEvents();
      }
      final s5 = prefs.getString('cache_meal_plans');
      if (s5 != null) {
        _mealPlans =
            (jsonDecode(s5) as List).map((e) => MealPlan.fromJson(e)).toList();
        _rebuildMealIndex();
      }
      _updateLatestActivityFromData();

      final sPending = prefs.getString('pending_uploads');
      if (sPending != null) {
        _pendingUploads = List<Map<String, dynamic>>.from(jsonDecode(sPending));
      }

      final didSeedExample =
          await _maybeSeedExampleInventoryItem(setFlag: false);
      if (didSeedExample) {
        await _saveLocalCache();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> _maybeSeedExampleInventoryItem({required bool setFlag}) async {
    if (_items.isNotEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final alreadySeeded = prefs.getBool(_kExampleInventorySeedKey) ?? false;
    if (alreadySeeded) return false;

    final now = DateTime.now();
    _items.insert(
      0,
      FoodItem(
        id: const Uuid().v4(),
        name: 'Apple',
        location: StorageLocation.fridge,
        quantity: 3,
        unit: 'pcs',
        purchasedDate: now,
        predictedExpiry: now.add(const Duration(days: 5)),
        category: 'produce',
        source: 'example',
        ownerName: 'Me',
      ),
    );

    if (setFlag) {
      await prefs.setBool(_kExampleInventorySeedKey, true);
    }
    return true;
  }

  Future<void> _loadLocalMeta() async {
    final prefs = await SharedPreferences.getInstance();
    hasShownPetWarning = prefs.getBool('petWarningShown') ?? false;
    _streakDays = prefs.getInt('streakDays') ?? 0;
    _isSharedUsage = prefs.getBool('is_shared_usage_v1') ?? true;
    await _loadCategoryMemory(prefs);
    final lastSeen = prefs.getString('last_seen_activity_v1');
    if (lastSeen != null) {
      _lastSeenActivityAt = DateTime.tryParse(lastSeen);
    }
    final phase = prefs.getString('migration_phase_v1');
    if (phase != null && phase.isNotEmpty) {
      _migrationPhase = MigrationPhase.values.firstWhere(
        (e) => e.name == phase,
        orElse: () => MigrationPhase.idle,
      );
    }
    final action = prefs.getString('migration_action_v1');
    if (action != null && action.isNotEmpty) {
      _migrationAction = MigrationAction.values.firstWhere(
        (e) => e.name == action,
        orElse: () => MigrationAction.join,
      );
    }
    _migrationMessage = prefs.getString('migration_message_v1');
    _migrationError = prefs.getString('migration_error_v1');
    _migrationAttempt = prefs.getInt('migration_attempt_v1') ?? 0;
    final updated = prefs.getString('migration_updated_v1');
    if (updated != null && updated.isNotEmpty) {
      _migrationUpdatedAt = DateTime.tryParse(updated);
    }
  }

  Future<void> _loadCategoryMemory(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_kCategoryMemoryKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _categoryMemory =
          decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {}
  }

  Future<void> _saveCategoryMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCategoryMemoryKey, jsonEncode(_categoryMemory));
    } catch (_) {}
  }

  String? inferCategoryForName(String name, {String? existingCategory}) {
    final normalized = _normalizeName(name);
    if (normalized.isNotEmpty) {
      final remembered = _categoryMemory[normalized];
      if (remembered != null && remembered.isNotEmpty) return remembered;

      final fromShopping = _categoryFromShopping(normalized);
      if (fromShopping != null) return fromShopping;

      final fromKeywords = _categoryFromKeywords(normalized, name);
      if (fromKeywords != null) return fromKeywords;
    }
    return _cleanCategoryKey(existingCategory);
  }

  bool isExplicitCategory(String? category) {
    return _cleanCategoryKey(category) != null;
  }

  Future<void> rememberCategoryForName(String name, String categoryKey) async {
    final normalized = _normalizeName(name);
    if (normalized.isEmpty) return;
    final cleaned = _cleanCategoryKey(categoryKey);
    if (cleaned == null) return;
    _categoryMemory[normalized] = cleaned;
    await _saveCategoryMemory();
  }

  String _normalizeName(String name) {
    var value = name.toLowerCase().trim();
    value = value.replaceAll(
        RegExp(r'[\(\)\[\]\{\},.;:!@#\$%\^&\*\-\+\=_~/\\|]'), ' ');
    value = value.replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff\s]'), ' ');
    final parts =
        value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    const stopWords = {
      'kg',
      'g',
      'gram',
      'grams',
      'ml',
      'l',
      'liter',
      'litre',
      'oz',
      'lb',
      'pcs',
      'pc',
      'pack',
      'pkg',
      'box',
      'bottle',
      'bag',
      'can',
      'jar',
      'ct',
      'dozen',
      'fresh',
      'organic',
      'low',
      'fat',
      'lowfat',
      'nonfat',
      'skim',
      'whole',
      'unsweetened',
      'sweetened',
      'light',
      'extra',
      'large',
      'small',
      'medium',
      'mini',
      'frozen',
      'raw',
      'cooked',
      'cut',
      'seedless',
      'boneless',
      'skinless',
    };

    final filtered = <String>[];
    for (final part in parts) {
      if (stopWords.contains(part)) continue;
      if (RegExp(r'^\d+(\.\d+)?$').hasMatch(part)) continue;
      filtered.add(part);
    }

    return filtered.join(' ');
  }

  String? _cleanCategoryKey(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (value == 'manual' || value == 'general' || value == 'unknown')
      return null;
    return value;
  }

  String? _categoryFromShopping(String normalizedName) {
    for (final item in _activeShoppingList) {
      final key = _normalizeName(item.name);
      if (key == normalizedName) {
        final cleaned = _cleanCategoryKey(item.category);
        if (cleaned != null) return cleaned;
      }
    }
    for (final item in _shoppingHistory) {
      final key = _normalizeName(item.name);
      if (key == normalizedName) {
        final cleaned = _cleanCategoryKey(item.category);
        if (cleaned != null) return cleaned;
      }
    }
    return null;
  }

  String? _categoryFromKeywords(String normalized, String original) {
    final n = normalized;
    final o = original.toLowerCase();

    if (_containsAny(n, o, [
      'apple',
      'banana',
      'tomato',
      'lettuce',
      'spinach',
      'vegetable',
      'veg',
      'carrot',
      'onion',
      'potato',
      'pepper',
      'cucumber',
      'broccoli',
      'mushroom',
      'fruit',
    ])) {
      return 'produce';
    }

    if (_containsAny(n, o, [
      'milk',
      'yogurt',
      'cheese',
      'butter',
      'cream',
      'egg',
    ])) {
      return 'dairy';
    }

    if (_containsAny(n, o, [
      'beef',
      'pork',
      'chicken',
      'turkey',
      'sausage',
      'ham',
      'bacon',
      'meat',
    ])) {
      return 'meat';
    }

    if (_containsAny(n, o, [
      'fish',
      'salmon',
      'shrimp',
      'tuna',
      'crab',
      'seafood',
    ])) {
      return 'seafood';
    }

    if (_containsAny(n, o, [
      'bread',
      'cake',
      'croissant',
      'bun',
      'bagel',
      'pastry',
      'flour',
    ])) {
      return 'bakery';
    }

    if (_containsAny(n, o, [
      'frozen',
      'ice cream',
      'dumpling',
      'pizza',
    ])) {
      return 'frozen';
    }

    if (_containsAny(n, o, [
      'water',
      'juice',
      'coffee',
      'tea',
      'beer',
      'wine',
      'soda',
      'drink',
    ])) {
      return 'beverage';
    }

    if (_containsAny(n, o, [
      'rice',
      'pasta',
      'noodle',
      'oil',
      'sauce',
      'salt',
      'sugar',
      'vinegar',
      'soy',
      'canned',
    ])) {
      return 'pantry';
    }

    if (_containsAny(n, o, [
      'snack',
      'chip',
      'chocolate',
      'cookie',
      'candy',
      'nuts',
      'cracker',
    ])) {
      return 'snacks';
    }

    if (_containsAny(n, o, [
      'paper',
      'tissue',
      'soap',
      'cleaner',
      'detergent',
      'toilet',
      'trash',
    ])) {
      return 'household';
    }

    if (_containsAny(n, o, [
      'cat',
      'dog',
      'pet',
      'kibble',
    ])) {
      return 'pet';
    }

    return null;
  }

  bool _containsAny(String normalized, String original, List<String> keywords) {
    for (final keyword in keywords) {
      if (keyword.isEmpty) continue;
      if (normalized.contains(keyword) || original.contains(keyword))
        return true;
    }
    return false;
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

    final activeDates = _impactEvents
        .map((e) {
          return DateTime(e.date.year, e.date.month, e.date.day);
        })
        .toSet()
        .toList();

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

  Future<bool> updateMyDisplayName(String name) async {
    if (_currentUserId == null) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    try {
      await _supabase.from('user_profiles').upsert({
        'id': _currentUserId,
        'display_name': trimmed,
      });
      try {
        await _supabase.auth
            .updateUser(UserAttributes(data: {'display_name': trimmed}));
      } catch (_) {}
      _currentUserName = trimmed;
      if (_currentUserId != null) {
        _familyMemberCache[_currentUserId!] = trimmed;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('updateMyDisplayName error -> $e');
      return false;
    }
  }

  Future<void> _refreshFamilyMemberCache() async {
    final members = await getFamilyMembers();
    _familyMemberCache = {
      for (var m in members) m['user_id'].toString(): m['name'].toString()
    };
  }

  Future<String> createInviteCode() async {
    if (_currentFamilyId == null) {
      await _initFamilySession();
    }
    if (_currentFamilyId == null)
      throw Exception(
          "System Error: No Family Context. Please check your connection.");

    final code = (100000 + Random().nextInt(900000)).toString();
    final expiresAt =
        DateTime.now().toUtc().add(const Duration(hours: 48)).toIso8601String();

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
      final invite = await _supabase
          .from('family_invites')
          .select()
          .eq('code', code)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .maybeSingle();
      if (invite == null) return false;
      if (_currentUserId == null) return false;

      final newFamilyId = invite['family_id']?.toString();
      if (newFamilyId == null || newFamilyId.isEmpty) return false;
      final oldFamilyId = _currentFamilyId;
      final userId = _currentUserId!;
      final shouldMigrate = oldFamilyId != null && oldFamilyId != newFamilyId;

      List<Map<String, dynamic>> myInventory = [];
      List<Map<String, dynamic>> myShopping = [];
      List<Map<String, dynamic>> myShoppingHistory = [];
      List<Map<String, dynamic>> myImpact = [];

      if (shouldMigrate) {
        _setMigrationState(
          MigrationPhase.preparing,
          action: MigrationAction.join,
          message: 'Preparing your data...',
        );
        try {
          final result =
              await _withRetry<Map<String, List<Map<String, dynamic>>>>(
            () async {
              final inventory = List<Map<String, dynamic>>.from(
                await _supabase
                    .from('inventory_items')
                    .select()
                    .eq('family_id', oldFamilyId)
                    .eq('user_id', userId),
              );
              final shopping = List<Map<String, dynamic>>.from(
                await _supabase
                    .from('shopping_items')
                    .select()
                    .eq('family_id', oldFamilyId)
                    .eq('user_id', userId),
              );
              final history = List<Map<String, dynamic>>.from(
                await _supabase
                    .from('shopping_history')
                    .select()
                    .eq('family_id', oldFamilyId)
                    .eq('user_id', userId),
              );
              final impact = List<Map<String, dynamic>>.from(
                await _supabase
                    .from('impact_events')
                    .select()
                    .eq('family_id', oldFamilyId)
                    .eq('user_id', userId),
              );
              return {
                'inventory': inventory,
                'shopping': shopping,
                'history': history,
                'impact': impact,
              };
            },
            stepLabel: 'Preparing your data...',
            action: MigrationAction.join,
          );
          myInventory = result['inventory'] ?? [];
          myShopping = result['shopping'] ?? [];
          myShoppingHistory = result['history'] ?? [];
          myImpact = result['impact'] ?? [];
        } catch (e) {
          _setMigrationState(
            MigrationPhase.failed,
            action: MigrationAction.join,
            message: 'Migration failed while preparing data.',
            error: e.toString(),
          );
          return false;
        }
      }

      try {
        await _withRetry(
          () => _supabase.from('family_members').upsert({
            'family_id': newFamilyId,
            'user_id': _currentUserId,
            'role': 'member'
          }, onConflict: 'family_id,user_id'),
          stepLabel: 'Joining new family...',
          action: MigrationAction.join,
        );
      } catch (e) {
        _setMigrationState(
          MigrationPhase.failed,
          action: MigrationAction.join,
          message: 'Failed to join new family.',
          error: e.toString(),
        );
        return false;
      }

      if (shouldMigrate) {
        _currentFamilyId = newFamilyId;
        try {
          if (myInventory.isNotEmpty) {
            final payloads = myInventory.map((item) {
              final payload = Map<String, dynamic>.from(item);
              payload['family_id'] = newFamilyId;
              payload['user_id'] = userId;
              return _cleanJsonForDb(payload, tableName: 'inventory_items');
            }).toList();
            await _withRetry(
              () => _supabase.from('inventory_items').upsert(payloads),
              stepLabel: 'Migrating inventory...',
              action: MigrationAction.join,
            );
          }
          if (myShopping.isNotEmpty) {
            final payloads = myShopping.map((item) {
              final payload = Map<String, dynamic>.from(item);
              payload['family_id'] = newFamilyId;
              payload['user_id'] = userId;
              return _cleanJsonForDb(payload, tableName: 'shopping_items');
            }).toList();
            await _withRetry(
              () => _supabase.from('shopping_items').upsert(payloads),
              stepLabel: 'Migrating shopping list...',
              action: MigrationAction.join,
            );
          }
          if (myShoppingHistory.isNotEmpty) {
            final payloads = myShoppingHistory.map((item) {
              final payload = Map<String, dynamic>.from(item);
              payload['family_id'] = newFamilyId;
              payload['user_id'] = userId;
              return _cleanJsonForDb(payload, tableName: 'shopping_history');
            }).toList();
            await _withRetry(
              () => _supabase.from('shopping_history').upsert(payloads),
              stepLabel: 'Migrating shopping history...',
              action: MigrationAction.join,
            );
          }
          if (myImpact.isNotEmpty) {
            final payloads = myImpact.map((item) {
              final payload = Map<String, dynamic>.from(item);
              payload['family_id'] = newFamilyId;
              payload['user_id'] = userId;
              return _cleanJsonForDb(payload, tableName: 'impact_events');
            }).toList();
            await _withRetry(
              () => _supabase.from('impact_events').upsert(payloads),
              stepLabel: 'Migrating impact data...',
              action: MigrationAction.join,
            );
          }

          await _withRetry(
            () async {
              await _supabase
                  .from('inventory_items')
                  .delete()
                  .eq('family_id', oldFamilyId)
                  .eq('user_id', userId);
              await _supabase
                  .from('shopping_items')
                  .delete()
                  .eq('family_id', oldFamilyId)
                  .eq('user_id', userId);
              await _supabase
                  .from('shopping_history')
                  .delete()
                  .eq('family_id', oldFamilyId)
                  .eq('user_id', userId);
            },
            stepLabel: 'Cleaning up old data...',
            action: MigrationAction.join,
          );
          await _withRetry(
            () => _supabase
                .from('family_members')
                .delete()
                .eq('family_id', oldFamilyId)
                .eq('user_id', userId),
            stepLabel: 'Finalizing...',
            action: MigrationAction.join,
          );
        } catch (e) {
          _setMigrationState(
            MigrationPhase.failed,
            action: MigrationAction.join,
            message: 'Migration failed while transferring data.',
            error: e.toString(),
          );
          return false;
        }
      }

      final tempUid = _currentUserId;
      _resetState();
      _currentUserId = tempUid;
      _currentFamilyId = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_inventory');
      await prefs.remove('cache_shopping');
      await prefs.remove('cache_history');
      await prefs.remove('cache_impact');
      await prefs.remove('cache_meal_plans');
      await prefs.remove('pending_uploads');

      await _initFamilySession();
      await _fetchAllData();
      if (shouldMigrate) {
        _setMigrationState(
          MigrationPhase.completed,
          action: MigrationAction.join,
          message: 'Migration completed.',
        );
      } else {
        _setMigrationState(
          MigrationPhase.idle,
          action: MigrationAction.join,
          message: '',
          error: null,
          attempt: 0,
        );
        await _clearMigrationMeta();
      }
      return true;
    } catch (e) {
      _setMigrationState(
        MigrationPhase.failed,
        action: MigrationAction.join,
        message: 'Migration failed.',
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> leaveFamily() async {
    if (_currentUserId == null || _currentFamilyId == null) return false;
    final oldFamilyId = _currentFamilyId!;
    final userId = _currentUserId!;
    List<Map<String, dynamic>> myInventory = [];
    List<Map<String, dynamic>> myShopping = [];
    List<Map<String, dynamic>> myShoppingHistory = [];
    List<Map<String, dynamic>> myImpact = [];
    try {
      _setMigrationState(
        MigrationPhase.preparing,
        action: MigrationAction.leave,
        message: 'Preparing your data...',
      );
      final result = await _withRetry<Map<String, List<Map<String, dynamic>>>>(
        () async {
          final inventory = List<Map<String, dynamic>>.from(
            await _supabase
                .from('inventory_items')
                .select()
                .eq('family_id', oldFamilyId)
                .eq('user_id', userId),
          );
          final shopping = List<Map<String, dynamic>>.from(
            await _supabase
                .from('shopping_items')
                .select()
                .eq('family_id', oldFamilyId)
                .eq('user_id', userId),
          );
          final history = List<Map<String, dynamic>>.from(
            await _supabase
                .from('shopping_history')
                .select()
                .eq('family_id', oldFamilyId)
                .eq('user_id', userId),
          );
          final impact = List<Map<String, dynamic>>.from(
            await _supabase
                .from('impact_events')
                .select()
                .eq('family_id', oldFamilyId)
                .eq('user_id', userId),
          );
          return {
            'inventory': inventory,
            'shopping': shopping,
            'history': history,
            'impact': impact,
          };
        },
        stepLabel: 'Preparing your data...',
        action: MigrationAction.leave,
      );
      myInventory = result['inventory'] ?? [];
      myShopping = result['shopping'] ?? [];
      myShoppingHistory = result['history'] ?? [];
      myImpact = result['impact'] ?? [];
    } catch (e) {
      _setMigrationState(
        MigrationPhase.failed,
        action: MigrationAction.leave,
        message: 'Migration failed while preparing data.',
        error: e.toString(),
      );
      return false;
    }

    try {
      final tempUid = _currentUserId;
      _resetState();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_inventory');
      await prefs.remove('cache_shopping');
      await prefs.remove('cache_history');
      await prefs.remove('cache_impact');
      await prefs.remove('cache_meal_plans');
      await prefs.remove('pending_uploads');

      _currentUserId = tempUid;
      await _createNewDefaultFamily(_currentUserId!);

      if (_currentFamilyId != null) {
        try {
          if (myInventory.isNotEmpty) {
            final payloads = myInventory.map((item) {
              final payload = Map<String, dynamic>.from(item);
              payload['family_id'] = _currentFamilyId;
              payload['user_id'] = _currentUserId;
              return _cleanJsonForDb(payload, tableName: 'inventory_items');
            }).toList();
            await _withRetry(
              () => _supabase.from('inventory_items').upsert(payloads),
              stepLabel: 'Migrating inventory...',
              action: MigrationAction.leave,
            );
          }
          if (myShopping.isNotEmpty) {
            final payloads = myShopping.map((item) {
              final payload = Map<String, dynamic>.from(item);
              payload['family_id'] = _currentFamilyId;
              payload['user_id'] = _currentUserId;
              return _cleanJsonForDb(payload, tableName: 'shopping_items');
            }).toList();
            await _withRetry(
              () => _supabase.from('shopping_items').upsert(payloads),
              stepLabel: 'Migrating shopping list...',
              action: MigrationAction.leave,
            );
          }
          if (myShoppingHistory.isNotEmpty) {
            final payloads = myShoppingHistory.map((item) {
              final payload = Map<String, dynamic>.from(item);
              payload['family_id'] = _currentFamilyId;
              payload['user_id'] = _currentUserId;
              return _cleanJsonForDb(payload, tableName: 'shopping_history');
            }).toList();
            await _withRetry(
              () => _supabase.from('shopping_history').upsert(payloads),
              stepLabel: 'Migrating shopping history...',
              action: MigrationAction.leave,
            );
          }
          if (myImpact.isNotEmpty) {
            final payloads = myImpact.map((item) {
              final payload = Map<String, dynamic>.from(item);
              payload['family_id'] = _currentFamilyId;
              payload['user_id'] = _currentUserId;
              return _cleanJsonForDb(payload, tableName: 'impact_events');
            }).toList();
            await _withRetry(
              () => _supabase.from('impact_events').upsert(payloads),
              stepLabel: 'Migrating impact data...',
              action: MigrationAction.leave,
            );
          }
        } catch (e) {
          _setMigrationState(
            MigrationPhase.failed,
            action: MigrationAction.leave,
            message: 'Migration failed while transferring data.',
            error: e.toString(),
          );
          return false;
        }
      }

      try {
        await _withRetry(
          () async {
            await _supabase
                .from('inventory_items')
                .delete()
                .eq('family_id', oldFamilyId)
                .eq('user_id', userId);
            await _supabase
                .from('shopping_items')
                .delete()
                .eq('family_id', oldFamilyId)
                .eq('user_id', userId);
            await _supabase
                .from('shopping_history')
                .delete()
                .eq('family_id', oldFamilyId)
                .eq('user_id', userId);
          },
          stepLabel: 'Cleaning up old data...',
          action: MigrationAction.leave,
        );
      } catch (e) {
        _setMigrationState(
          MigrationPhase.failed,
          action: MigrationAction.leave,
          message: 'Migration failed while cleaning up old data.',
          error: e.toString(),
        );
        return false;
      }

      try {
        await _withRetry(
          () => _supabase
              .from('family_members')
              .delete()
              .eq('family_id', oldFamilyId)
              .eq('user_id', userId),
          stepLabel: 'Finalizing...',
          action: MigrationAction.leave,
        );
      } catch (e) {
        _setMigrationState(
          MigrationPhase.failed,
          action: MigrationAction.leave,
          message: 'Migration failed while finalizing.',
          error: e.toString(),
        );
        return false;
      }
      await _fetchAllData();
      _setMigrationState(
        MigrationPhase.completed,
        action: MigrationAction.leave,
        message: 'Migration completed.',
      );
      return true;
    } catch (e) {
      _setMigrationState(
        MigrationPhase.failed,
        action: MigrationAction.leave,
        message: 'Migration failed.',
        error: e.toString(),
      );
      return false;
    }
  }
}
