import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // NOTE: legacy comment cleaned.
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/guest_shopping.dart';
import '../repositories/guest_shopping_repository.dart';
import '../l10n/app_localizations.dart';
import '../utils/share_link_builder.dart';
import '../utils/web_reload.dart';

class GuestShoppingListPage extends StatefulWidget {
  final String shareToken;
  final bool lookupById;

  const GuestShoppingListPage({
    super.key,
    required this.shareToken,
    this.lookupById = false,
  });

  // NOTE: legacy comment cleaned.
  static String? resolveToken(RouteSettings settings) {
    // NOTE: legacy comment cleaned.
    final args = settings.arguments;
    if (args is String && args.trim().isNotEmpty) return args.trim();
    
    // NOTE: legacy comment cleaned.
    if (settings.name != null) {
      final uri = Uri.tryParse(settings.name!);
      final pathSegments = uri?.pathSegments ?? const <String>[];
      if (pathSegments.isNotEmpty && pathSegments.first == 'share' && pathSegments.length > 1) {
        return pathSegments[1];
      }
      final token = uri?.queryParameters['token'];
      if (token != null && token.isNotEmpty) return token;
    }

    // NOTE: legacy comment cleaned.
    final fragment = Uri.base.fragment;
    if (fragment.isNotEmpty) {
      var frag = fragment;
      if (frag.startsWith('#')) frag = frag.substring(1);
      if (frag.startsWith('/#/')) frag = frag.substring(2);
      if (frag.startsWith('#/')) frag = frag.substring(1);
      final fragUri = Uri.tryParse(frag.startsWith('/') ? frag : '/$frag');
      final fragSegments = fragUri?.pathSegments ?? const <String>[];
      if (fragSegments.isNotEmpty) {
        if (fragSegments.first == 'share' && fragSegments.length > 1) {
          return fragSegments[1];
        }
        if (fragSegments.first == '#' && fragSegments.length > 2 && fragSegments[1] == 'share') {
          return fragSegments[2];
        }
      }
      final token = fragUri?.queryParameters['token'];
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  @override
  State<GuestShoppingListPage> createState() => _GuestShoppingListPageState();
}

class _GuestShoppingListPageState extends State<GuestShoppingListPage> {
  // NOTE: legacy comment cleaned.
  late GuestShoppingRepository _repo;
  final TextEditingController _inputController = TextEditingController();
  
  static const String _guestNameKey = 'guest_editor_name_v1';
  static const String _forceReloadKeyPrefix = 'guest_list_force_reload_timestamp_v2_'; 
  
  bool _didRetryLoad = false;
  bool _isRetrying = false;
  bool _isInitializing = true; // NOTE: legacy comment cleaned.
  bool _didAutoBack = false;

  @override
  void initState() {
    super.initState();
    // NOTE: legacy comment cleaned.
    _repo = GuestShoppingRepository(
      shareToken: widget.shareToken,
      lookupById: widget.lookupById,
    );
    _repo.addListener(_onRepoChanged);
    
    // NOTE: legacy comment cleaned.
    _initLoad();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    _repo.disposeRealtime();
    _inputController.dispose();
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  // NOTE: legacy comment cleaned.
  Future<void> _initLoad() async {
    if (mounted) setState(() => _isInitializing = true);

    try {
      // NOTE: legacy comment cleaned.
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // NOTE: legacy comment cleaned.
      // NOTE: legacy comment cleaned.
      await _waitForAuthSession();

      // NOTE: legacy comment cleaned.
      await _reverifyToken();

      // NOTE: legacy comment cleaned.
      await _loadGuestName();

      // NOTE: legacy comment cleaned.
      await _repo.load();

      // NOTE: legacy comment cleaned.
      if (_repo.error == null) {
        await _clearForceReloadFlag();
      } else {
        await _handleLoadError();
      }
    } catch (e) {
      debugPrint('Init load error: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  // NOTE: legacy comment cleaned.
  Future<void> _waitForAuthSession() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return;

    debugPrint('GuestList: No session found, waiting or signing in anonymously...');
    
    // NOTE: legacy comment cleaned.
    try {
      await auth.onAuthStateChange.firstWhere(
        (data) => data.session != null,
      ).timeout(const Duration(seconds: 2));
    } catch (_) {
      // NOTE: legacy comment cleaned.
      if (auth.currentSession == null) {
        debugPrint('GuestList: Still no session, forcing anonymous sign in.');
        try {
          await auth.signInAnonymously();
        } catch (e) {
          debugPrint('GuestList: Anonymous sign in failed: $e');
          // NOTE: legacy comment cleaned.
        }
      }
    }
  }

  // NOTE: legacy comment cleaned.
  Future<void> _reverifyToken() async {
    if (!kIsWeb) return;
    
    // NOTE: legacy comment cleaned.
    final urlToken = GuestShoppingListPage.resolveToken(const RouteSettings());
    
    // NOTE: legacy comment cleaned.
    // NOTE: legacy comment cleaned.
    if (urlToken != null && urlToken.isNotEmpty && urlToken != _repo.shareToken) {
      debugPrint('GuestList: Token mismatch detected. Replacing "${_repo.shareToken}" with "$urlToken"');
      
      // NOTE: legacy comment cleaned.
      _repo.removeListener(_onRepoChanged);
      _repo.disposeRealtime();

      // NOTE: legacy comment cleaned.
      _repo = GuestShoppingRepository(
        shareToken: urlToken,
        lookupById: widget.lookupById,
      );
      _repo.addListener(_onRepoChanged);
    }
  }

  // NOTE: legacy comment cleaned.
  Future<void> _handleLoadError() async {
    if (_repo.error != null &&
        _repo.error!.toLowerCase().contains('not found') &&
        !_didRetryLoad) {
      _didRetryLoad = true;
      if (mounted) setState(() => _isRetrying = true);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (mounted && !_didAutoBack && Navigator.of(context).canPop()) {
        _didAutoBack = true;
        if (mounted) setState(() => _isRetrying = false);
        Navigator.of(context).pop();
        return;
      }
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _loadGuestName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_guestNameKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _repo.setGuestName(saved.trim());
    }
  }

  Future<void> _clearForceReloadFlag() async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_forceReloadKeyPrefix${widget.shareToken}';
    if (prefs.containsKey(key)) {
      await prefs.remove(key);
    }
  }

  Future<bool> _ensureGuestName() async {
    final l10n = AppLocalizations.of(context);
    final requiresName = _repo.isLoggedIn
        ? (_repo.currentUserName == null || _repo.currentUserName!.trim().isEmpty)
        : true;
    if (!requiresName) return true;
    final current = _repo.guestName;
    if (current != null && current.trim().isNotEmpty) return true;
    final controller = TextEditingController();
    final saved = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(l10n?.guestListAddYourNameTitle ?? 'Add your name'),
          content: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n?.guestListEnterDisplayNameHint ?? 'Enter a display name',
              filled: true,
              fillColor: theme.cardColor,
            ),
            onSubmitted: (_) => Navigator.pop(ctx, controller.text),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(l10n?.cancel ?? 'Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ],
        );
      },
    );
    final trimmed = saved?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestNameKey, trimmed);
    _repo.setGuestName(trimmed);
    await _repo.syncGuestName(trimmed);
    return true;
  }

  Future<void> _addItem() async {
    if (_repo.isExpired) {
      _showExpiredMessage();
      return;
    }
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (!await _ensureGuestName()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final item = GuestShoppingItem(
      id: const Uuid().v4(),
      listId: _repo.list?.id ?? '',
      name: text,
      quantity: null,
      unit: null,
      isChecked: false,
      note: null,
      updatedBy: userId,
      editorName: _repo.isLoggedIn ? null : _repo.guestName,
      editorEmail: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _inputController.clear();
    await _repo.addItem(item);
  }

  Future<void> _toggleItem(GuestShoppingItem item, bool checked) async {
    if (_repo.isExpired) {
      _showExpiredMessage();
      return;
    }
    if (!await _ensureGuestName()) return;
    await _repo.toggleItem(item, checked);
  }

  Future<void> _deleteItem(GuestShoppingItem item) async {
    if (_repo.isExpired) {
      _showExpiredMessage();
      return;
    }
    if (!await _ensureGuestName()) return;
    await _repo.deleteItem(item);
  }

  Future<void> _editNote(GuestShoppingItem item) async {
    final l10n = AppLocalizations.of(context);
    if (_repo.isExpired) {
      _showExpiredMessage();
      return;
    }
    if (!await _ensureGuestName()) return;
    final controller = TextEditingController(text: item.note ?? '');
    final saved = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(l10n?.guestListAddNoteTitle ?? 'Add note'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n?.guestListAddNoteHint ?? 'e.g. low fat, brand, size',
              filled: true,
              fillColor: theme.cardColor,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(l10n?.cancel ?? 'Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ],
        );
      },
    );
    if (saved == null) return;
    await _repo.updateNote(item, saved);
  }

  Future<void> _toggleOwnership() async {
    if (!_repo.isLoggedIn) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isOwned = userId != null && _repo.list?.ownerId == userId;
    await _repo.attachToOwner(attach: !isOwned);
  }

  void _copyShareLink() {
    final token = (_repo.list?.shareToken ?? widget.shareToken).trim();
    final url = _buildShareUrl(token);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)?.guestListShareLinkCopied ?? 'Share link copied.')),
    );
  }

  String _buildShareUrl(String token) {
    return buildGuestShareUrl(token);
  }

  void _showExpiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.guestListExpiredEditingDisabled ??
              'This list has expired. Editing is disabled.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final list = _repo.list;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isOwned = userId != null && list?.ownerId == userId;
    final isExpired = _repo.isExpired;
    final needsName = (_repo.isLoggedIn
            ? (_repo.currentUserName == null || _repo.currentUserName!.trim().isEmpty)
            : (_repo.guestName == null || _repo.guestName!.trim().isEmpty));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          list?.title ?? (AppLocalizations.of(context)?.guestListTitle ?? 'Guest List'),
          style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)?.guestListCopyShareLinkTooltip ?? 'Copy share link',
            icon: Icon(Icons.link_rounded, color: colors.onSurface),
            onPressed: _copyShareLink,
          ),
          if (_repo.isLoggedIn)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)?.guestListMineLabel ?? 'Mine',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Switch.adaptive(
                    value: isOwned,
                    onChanged: (_) => _toggleOwnership(),
                    activeColor: colors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
      // NOTE: legacy comment cleaned.
      // NOTE: legacy comment cleaned.
      // NOTE: legacy comment cleaned.
      // NOTE: legacy comment cleaned.
      // NOTE: legacy comment cleaned.
      // NOTE: legacy comment cleaned.
      body: (_isInitializing || (_repo.isLoading && !_isRetrying))
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)?.guestListJoining ?? 'Joining list...',
                    style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            )
          : (_repo.error != null || _isRetrying)
              ? _buildErrorState(colors.onSurface)
              : RefreshIndicator(
                  onRefresh: _repo.load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      if (isExpired)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)?.guestListExpiredEditingDisabled ?? 'This list has expired. Editing is disabled.',
                                  style: TextStyle(
                                    color: colors.onSurface.withValues(alpha: 0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (needsName)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 18, color: colors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)?.guestListAddNameToEdit ?? 'Add your name to edit this list.',
                                  style: TextStyle(
                                    color: colors.onSurface.withValues(alpha: 0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _ensureGuestName,
                                child: Text(AppLocalizations.of(context)?.guestListAddNameAction ?? 'Add name'),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inputController,
                                onSubmitted: (_) => _addItem(),
                                enabled: !isExpired && !needsName,
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.of(context)?.shoppingAddItemHint ?? 'Add item',
                                  isDense: true,
                                  filled: true,
                                  fillColor: theme.cardColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.3)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.add_circle_rounded),
                              color: colors.primary,
                              onPressed: (isExpired || needsName) ? null : _addItem,
                            ),
                          ],
                        ),
                      ),
                      if (_repo.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: _buildEmptyState(colors.onSurface),
                        )
                      else
                        ..._repo.items.map((item) => Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: _GuestItemTile(
                                item: item,
                                enabled: !isExpired,
                                fallbackName: _repo.guestName,
                                onToggle: (checked) => _toggleItem(item, checked),
                                onDelete: () => _deleteItem(item),
                                onEditNote: () => _editNote(item),
                              ),
                            )),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Text(
        AppLocalizations.of(context)?.guestListNoItemsYet ?? 'No items yet.',
        style: TextStyle(color: textColor.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildErrorState(Color textColor) {
    if (_isRetrying || (_repo.isLoading && _didRetryLoad)) {
       return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.guestListLookingForList ?? 'Looking for list...',
              style: TextStyle(color: textColor.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    final err = _repo.error ?? (AppLocalizations.of(context)?.guestListFailedLoad ?? 'Failed to load list.');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              err,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () {
                // NOTE: legacy comment cleaned.
                // NOTE: legacy comment cleaned.
                // NOTE: legacy comment cleaned.
                // NOTE: legacy comment cleaned.
                setState(() {
                  _didRetryLoad = false; 
                  _isRetrying = false;
                  _isInitializing = true;
                });
                _initLoad();
              },
              child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: reloadPage,
                child: Text(AppLocalizations.of(context)?.guestListRefreshPage ?? 'Refresh Page'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _GuestItemTile extends StatelessWidget {
  final GuestShoppingItem item;
  final bool enabled;
  final String? fallbackName;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEditNote;

  const _GuestItemTile({
    required this.item,
    required this.enabled,
    required this.fallbackName,
    required this.onToggle,
    required this.onDelete,
    required this.onEditNote,
  });

  String _displayName(BuildContext context) {
    final name = item.editorName ?? '';
    final email = item.editorEmail ?? '';
    if (name.trim().isNotEmpty) return name.trim();
    if (email.trim().isNotEmpty) return email.trim();
    final fallback = fallbackName ?? '';
    if (fallback.trim().isNotEmpty) return fallback.trim();
    return AppLocalizations.of(context)?.guestListGuestFallback ?? 'Guest';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? () => onToggle(!item.isChecked) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: item.isChecked,
                onChanged: enabled ? (v) => onToggle(v ?? false) : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: item.isChecked || !enabled
                            ? colors.onSurface.withValues(alpha: 0.4)
                            : colors.onSurface,
                        decoration: item.isChecked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (item.note != null && item.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.note!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                          _displayName(context),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.notes_rounded,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
                tooltip: AppLocalizations.of(context)?.guestListAddNoteTitle ?? 'Add note',
                onPressed: enabled ? onEditNote : null,
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
                onPressed: enabled ? onDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



