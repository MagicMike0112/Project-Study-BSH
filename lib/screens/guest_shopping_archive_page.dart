import 'package:flutter/material.dart';

import '../models/guest_shopping.dart';
import '../repositories/guest_shopping_repository.dart';
import '../l10n/app_localizations.dart';
import 'guest_shopping_list_page.dart';

class GuestShoppingArchivePage extends StatefulWidget {
  const GuestShoppingArchivePage({super.key});

  @override
  State<GuestShoppingArchivePage> createState() => _GuestShoppingArchivePageState();
}

class _GuestShoppingArchivePageState extends State<GuestShoppingArchivePage> {
  bool _loading = true;
  String? _error;
  List<GuestShoppingList> _lists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lists = await GuestShoppingRepository.fetchMyLists();
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openList(GuestShoppingList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestShoppingListPage(
          shareToken: list.shareToken,
          lookupById: false,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n?.shoppingGuestMyListsTitle ?? 'My Guest Lists',
          style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
                  ),
                )
              : _lists.isEmpty
                  ? Center(
                      child: Text(
                        l10n?.guestArchiveEmpty ?? 'No guest lists yet.',
                        style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _lists.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final list = _lists[index];
                          final expired = list.expiresAt.isBefore(DateTime.now());
                          return _GuestListTile(
                            list: list,
                            expired: expired,
                            onTap: () => _openList(list),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _GuestListTile extends StatelessWidget {
  final GuestShoppingList list;
  final bool expired;
  final VoidCallback onTap;

  const _GuestListTile({
    required this.list,
    required this.expired,
    required this.onTap,
  });

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final badgeColor = expired ? Colors.red : Colors.green;
    final badgeBg = badgeColor.withValues(alpha: 0.12);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.list_alt_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.guestArchiveExpires(_formatDate(list.expiresAt)) ??
                          'Expires ${_formatDate(list.expiresAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  expired
                      ? (l10n?.guestArchiveExpired ?? 'Expired')
                      : (l10n?.guestArchiveActive ?? 'Active'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


