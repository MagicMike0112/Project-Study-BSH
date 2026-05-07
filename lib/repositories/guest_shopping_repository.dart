import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/guest_shopping.dart';
import '../utils/supabase_config.dart';

class GuestShoppingRepository extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  late final SupabaseClient _guestClient;
  late final SupabaseClient _authedGuestClient;
  final String shareToken;
  final bool lookupById;

  GuestShoppingList? _list;
  List<GuestShoppingItem> _items = [];
  bool _loading = false;
  String? _error;
  RealtimeChannel? _itemsChannel;
  String? _guestName;
  Timer? _pollTimer;
  bool _polling = false;

  GuestShoppingRepository({required this.shareToken, this.lookupById = false}) {
    _guestClient = SupabaseClient(
      kSupabaseUrl,
      kSupabaseAnonKey,
      headers: {'x-guest-token': shareToken},
    );
    _authedGuestClient = SupabaseClient(
      kSupabaseUrl,
      kSupabaseAnonKey,
      headers: {'x-guest-token': shareToken},
      accessToken: () async => _client.auth.currentSession?.accessToken,
    );
  }

  bool get isLoading => _loading;
  String? get error => _error;
  GuestShoppingList? get list => _list;
  List<GuestShoppingItem> get items => List.unmodifiable(_items);
  bool get isLoggedIn => _client.auth.currentUser != null;
  String? get guestName => _guestName;
  String? get currentUserName => _currentUserName;
  bool get isExpired => _list != null && _list!.expiresAt.isBefore(DateTime.now());
  String? get effectiveEditorName => _currentUserName ?? _guestName;

  SupabaseClient get _readClient => isLoggedIn ? _authedGuestClient : _guestClient;

  SupabaseClient get _writeClient => isLoggedIn ? _authedGuestClient : _guestClient;

  String? get _currentUserEmail => _client.auth.currentUser?.email;
  String? get _currentUserName =>
      _client.auth.currentUser?.userMetadata?['display_name']?.toString();
  void setGuestName(String? name) {
    final trimmed = name?.trim();
    _guestName = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    notifyListeners();
  }

  Future<void> syncGuestName(String name) async {
    if (_list == null) return;
    if (isExpired) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      final updated = await _writeClient
          .from('guest_shopping_lists')
          .update({'guest_display_name': trimmed})
          .eq('id', _list!.id)
          .select()
          .single();
      _list = GuestShoppingList.fromJson(Map<String, dynamic>.from(updated));
    } catch (_) {
      // Best-effort: local name still used.
    }
  }

  static Future<GuestShoppingList> createList({
    required String title,
    required Duration expiresIn,
    required bool attachToOwner,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final participants = userId == null ? const <String>[] : [userId];
    final payload = {
      'title': title.trim().isEmpty ? 'Guest List' : title.trim(),
      'expires_at': DateTime.now().toUtc().add(expiresIn).toIso8601String(),
      'owner_id': attachToOwner ? userId : null,
      'allow_guests': true,
      'participants': participants,
    };
    final response = await client.from('guest_shopping_lists').insert(payload).select().single();
    return GuestShoppingList.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> load() async {
    _setLoading(true);
    try {
      Map<String, dynamic>? listResp;
      for (int attempt = 0; attempt < 3; attempt++) {
        listResp = lookupById
            ? await _readClient
                .from('guest_shopping_lists')
                .select()
                .eq('id', shareToken)
                .maybeSingle()
            : await _readClient
                .from('guest_shopping_lists')
                .select()
                .eq('share_token', shareToken)
                .maybeSingle();
        if (listResp != null) break;
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 400));
        } else if (attempt == 1) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
      if (listResp == null) {
        _list = null;
        _items = [];
        _error = 'List not found or expired.';
        _setLoading(false);
        return;
      }
      _list = GuestShoppingList.fromJson(Map<String, dynamic>.from(listResp));
      if (_guestName == null || _guestName!.trim().isEmpty) {
        final syncedName = _list?.guestDisplayName;
        if (syncedName != null && syncedName.trim().isNotEmpty) {
          _guestName = syncedName.trim();
        }
      }
      await _ensureParticipant();

      final itemsResp = await _readClient
          .from('guest_shopping_items')
          .select('*, user_profiles(display_name, email)')
          .eq('list_id', _list!.id)
          .order('created_at', ascending: true);
      _items = (itemsResp as List)
          .map((e) => GuestShoppingItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _error = null;
      _setLoading(false);
      if (isLoggedIn) {
        _stopGuestPolling();
        _subscribeToRealtime();
      } else {
        disposeRealtime();
        _startGuestPolling();
      }
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  Future<void> attachToOwner({required bool attach}) async {
    if (_list == null) return;
    final userId = _client.auth.currentUser?.id;
    final payload = {'owner_id': attach ? userId : null};
    final updated = await _authedGuestClient
        .from('guest_shopping_lists')
        .update(payload)
        .eq('id', _list!.id)
        .select()
        .single();
    _list = GuestShoppingList.fromJson(Map<String, dynamic>.from(updated));
    notifyListeners();
  }

  Future<void> _ensureParticipant() async {
    if (!isLoggedIn || _list == null) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    if (_list!.participants.contains(userId)) return;
    final updatedParticipants = {..._list!.participants, userId}.toList();
    final updated = await _authedGuestClient
        .from('guest_shopping_lists')
        .update({'participants': updatedParticipants})
        .eq('id', _list!.id)
        .select()
        .single();
    _list = GuestShoppingList.fromJson(Map<String, dynamic>.from(updated));
    notifyListeners();
  }

  static Future<List<GuestShoppingList>> fetchMyLists() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final resp = await client
        .from('guest_shopping_lists')
        .select()
        .or('owner_id.eq.$userId,participants.cs.{\"$userId\"}')
        .order('updated_at', ascending: false);
    return (resp as List)
        .map((e) => GuestShoppingList.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addItem(GuestShoppingItem item) async {
    if (_list == null) return;
    if (isExpired) return;
    final userId = _client.auth.currentUser?.id;
    final editorName = isLoggedIn ? effectiveEditorName : _guestName;
    final editorEmail = isLoggedIn ? _currentUserEmail : null;
    final localItem = GuestShoppingItem(
      id: item.id,
      listId: item.listId,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      isChecked: item.isChecked,
      note: item.note,
      updatedBy: userId,
      editorName: editorName,
      editorEmail: editorEmail,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
    );
    _upsertLocal(localItem);
    await _writeClient.from('guest_shopping_items').upsert(localItem.toDbJson(_list!.id, userId));
  }

  Future<void> toggleItem(GuestShoppingItem item, bool checked) async {
    if (_list == null) return;
    if (isExpired) return;
    final editorName = isLoggedIn ? (effectiveEditorName ?? item.editorName) : (_guestName ?? item.editorName);
    final editorEmail = isLoggedIn ? _currentUserEmail : item.editorEmail;
    final updated = GuestShoppingItem(
      id: item.id,
      listId: item.listId,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      isChecked: checked,
      note: item.note,
      updatedBy: _client.auth.currentUser?.id ?? item.updatedBy,
      editorName: editorName,
      editorEmail: editorEmail,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
    );
    _upsertLocal(updated);
    await _writeClient.from('guest_shopping_items').upsert(updated.toDbJson(_list!.id, _client.auth.currentUser?.id));
  }

  Future<void> updateNote(GuestShoppingItem item, String? note) async {
    if (_list == null) return;
    if (isExpired) return;
    final cleaned = (note ?? '').trim();
    final editorName = isLoggedIn ? (effectiveEditorName ?? item.editorName) : (_guestName ?? item.editorName);
    final editorEmail = isLoggedIn ? _currentUserEmail : item.editorEmail;
    final updated = GuestShoppingItem(
      id: item.id,
      listId: item.listId,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      isChecked: item.isChecked,
      note: cleaned.isEmpty ? null : cleaned,
      updatedBy: _client.auth.currentUser?.id ?? item.updatedBy,
      editorName: editorName,
      editorEmail: editorEmail,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
    );
    _upsertLocal(updated);
    await _writeClient.from('guest_shopping_items').upsert(updated.toDbJson(_list!.id, _client.auth.currentUser?.id));
  }

  Future<void> deleteItem(GuestShoppingItem item) async {
    if (_list == null) return;
    if (isExpired) return;
    _items.removeWhere((e) => e.id == item.id);
    notifyListeners();
    await _writeClient.from('guest_shopping_items').delete().eq('id', item.id);
  }

  void disposeRealtime() {
    if (_itemsChannel != null) {
      _readClient.removeChannel(_itemsChannel!);
      _itemsChannel = null;
    }
  }

  @override
  void dispose() {
    _stopGuestPolling();
    disposeRealtime();
    super.dispose();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _upsertLocal(GuestShoppingItem item) {
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx == -1) {
      _items.add(item);
    } else {
      if (item.updatedAt.isAfter(_items[idx].updatedAt)) {
        _items[idx] = item;
      }
    }
    notifyListeners();
  }

  Future<void> _mergeRemoteRecord(Map<String, dynamic> record) async {
    final incoming = GuestShoppingItem.fromJson(record);
    final idx = _items.indexWhere((e) => e.id == incoming.id);
    if (idx == -1 || incoming.updatedAt.isAfter(_items[idx].updatedAt)) {
      final merged = await _fetchItemWithProfile(incoming.id) ?? incoming;
      _upsertLocal(merged);
    }
  }

  Future<GuestShoppingItem?> _fetchItemWithProfile(String id) async {
    try {
      final resp = await _readClient
          .from('guest_shopping_items')
          .select('*, user_profiles(display_name, email)')
          .eq('id', id)
          .maybeSingle();
      if (resp == null) return null;
      return GuestShoppingItem.fromJson(Map<String, dynamic>.from(resp));
    } catch (_) {
      return null;
    }
  }

  Future<void> _reloadItems() async {
    if (_list == null || _polling) return;
    _polling = true;
    try {
      final itemsResp = await _readClient
          .from('guest_shopping_items')
          .select('*, user_profiles(display_name, email)')
          .eq('list_id', _list!.id)
          .order('created_at', ascending: true);
      _items = (itemsResp as List)
          .map((e) => GuestShoppingItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _error = null;
      notifyListeners();
    } catch (_) {
      // Keep last known state; polling will retry.
    } finally {
      _polling = false;
    }
  }

  void _startGuestPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _reloadItems());
  }

  void _stopGuestPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _subscribeToRealtime() {
    if (_list == null || _itemsChannel != null) return;
    _itemsChannel = _readClient
        .channel('public:guest_shopping_items:${_list!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'guest_shopping_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'list_id',
            value: _list!.id,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            _mergeRemoteRecord(record);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'guest_shopping_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'list_id',
            value: _list!.id,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            _mergeRemoteRecord(record);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'guest_shopping_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'list_id',
            value: _list!.id,
          ),
          callback: (payload) {
            final record = payload.oldRecord;
            final id = record['id']?.toString();
            if (id == null) return;
            _items.removeWhere((e) => e.id == id);
            notifyListeners();
          },
        )
        .subscribe();
  }
}

