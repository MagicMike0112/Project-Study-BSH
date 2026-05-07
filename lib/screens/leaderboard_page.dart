// lib/screens/leaderboard_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _loadingWorld = true;
  String? _loadError;
  List<_LeaderboardEntry> _worldEntries = const [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboards();
  }

  Future<void> _loadLeaderboards() async {
    setState(() {
      _loadingWorld = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _loadWorldLeaderboard(),
      ]);
      if (!mounted) return;
      setState(() {
        _worldEntries = results[0];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWorld = false;
        });
      }
    }
  }

  DateTime _startOfWeek(DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    return start.subtract(Duration(days: start.weekday - 1));
  }

  Future<List<_LeaderboardEntry>> _loadWorldLeaderboard() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final range = _weekRange();
    final raw = await _client.rpc('weekly_leaderboard', params: {
      'start_ts': range.start.toIso8601String(),
      'end_ts': range.end.toIso8601String(),
      'limit_count': 1000,
    });
    final rows = List<Map<String, dynamic>>.from(raw as List);
    final ids = rows.map((e) => e['user_id'].toString()).toList();
    final profiles = await _fetchProfiles(ids);
    final stats = <String, _UserStat>{};
    for (final row in rows) {
      final id = row['user_id'].toString();
      final points = (row['points'] as num?)?.toDouble() ?? 0.0;
      stats[id] = _UserStat(points: points, days: {});
    }
    return _buildEntries(stats, profiles, user.id);
  }

  _WeekRange _weekRange() {
    final now = DateTime.now();
    final start = _startOfWeek(now);
    return _WeekRange(start: start, end: start.add(const Duration(days: 7)));
  }

  Map<String, String> _fetchProfilesResultToMap(List<Map<String, dynamic>> rows) {
    final map = <String, String>{};
    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null) continue;
      final displayName = row['display_name']?.toString().trim();
      final email = row['email']?.toString().trim();
      final name = _resolveProfileName(displayName, email);
      map[id] = name;
    }
    return map;
  }

  String _resolveProfileName(String? displayName, String? email) {
    if (displayName != null && displayName.isNotEmpty) return displayName;
    if (email != null && email.isNotEmpty) return _maskEmail(email);
    return 'User';
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    final local = parts.first;
    final visible = local.length <= 4 ? local : local.substring(0, 4);
    return '$visible***';
  }

  Future<Map<String, String>> _fetchProfiles(List<String> ids) async {
    if (ids.isEmpty) return {};
    final res = await _client
        .from('user_profiles')
        .select('id, display_name, email')
        .inFilter('id', ids);
    return _fetchProfilesResultToMap(List<Map<String, dynamic>>.from(res));
  }

  List<_LeaderboardEntry> _buildEntries(
    Map<String, _UserStat> stats,
    Map<String, String> profiles,
    String currentUserId,
  ) {
    final entries = stats.entries.map((entry) {
      final userId = entry.key;
      final data = entry.value;
      return _LeaderboardEntry(
        rank: 0,
        name: profiles[userId] ?? 'User',
        points: data.points,
        streak: _calculateStreak(data.days),
        isMe: userId == currentUserId,
        color: userId == currentUserId ? const Color(0xFF58CC02) : const Color(0xFF2B70C9),
      );
    }).toList();
    entries.sort((a, b) => b.points.compareTo(a.points));
    for (var i = 0; i < entries.length; i++) {
      entries[i] = entries[i].copyWith(rank: i + 1);
    }
    return entries;
  }

  int _calculateStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final yesterday = todayDay.subtract(const Duration(days: 1));
    if (sorted.first != todayDay && sorted.first != yesterday) return 0;
    var streak = 1;
    for (var i = 0; i < sorted.length - 1; i++) {
      if (sorted[i].difference(sorted[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final global = _worldEntries;
    final myGlobal = global.firstWhere((e) => e.isMe, orElse: () => global.isNotEmpty ? global.first : _LeaderboardEntry.emptyMe());

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF131F24) : const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF202F36) : Colors.white,
            elevation: 0,
            titleSpacing: 16,
            title: Text(
              AppLocalizations.of(context)?.leaderboardTitle ?? 'Leaderboard',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: colors.onSurface,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  if (_loadError != null)
                    _ErrorCard(
                      message: _loadError!,
                      onRetry: _loadLeaderboards,
                    )
                  else
                    _HeroRankCard(
                      entry: myGlobal,
                      scopeLabel: AppLocalizations.of(context)?.leaderboardScopeWorld ?? 'World',
                    ),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: AppLocalizations.of(context)?.leaderboardGlobalTitle ?? 'Global',
                    subtitle: AppLocalizations.of(context)?.leaderboardGlobalSubtitle ?? 'Top performers worldwide',
                    icon: Icons.public_rounded,
                  ),
                  const SizedBox(height: 10),
                  if (_loadingWorld)
                    const _LoadingList()
                  else
                    _LeaderboardList(entries: global, compact: true),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekRange {
  final DateTime start;
  final DateTime end;

  const _WeekRange({required this.start, required this.end});
}

class _UserStat {
  double points;
  final Set<DateTime> days;

  _UserStat({required this.points, required this.days});
}

class _LeaderboardEntry {
  final int rank;
  final String name;
  final double points;
  final int streak;
  final bool isMe;
  final Color color;

  const _LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.points,
    required this.streak,
    this.isMe = false,
    required this.color,
  });
  _LeaderboardEntry copyWith({int? rank}) {
    return _LeaderboardEntry(
      rank: rank ?? this.rank,
      name: name,
      points: points,
      streak: streak,
      isMe: isMe,
      color: color,
    );
  }

  static _LeaderboardEntry emptyMe() {
    return const _LeaderboardEntry(
      rank: 0,
      name: 'You',
      points: 0,
      streak: 0,
      isMe: true,
      color: Color(0xFF58CC02),
    );
  }
}

class _HeroRankCard extends StatelessWidget {
  final _LeaderboardEntry entry;
  final String scopeLabel;

  const _HeroRankCard({required this.entry, required this.scopeLabel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202F36) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          _RankBadge(rank: entry.rank, color: entry.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.leaderboardYourRank ?? 'Your Rank',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.rank == 0
                      ? (AppLocalizations.of(context)?.leaderboardNoDataYet ?? 'No data yet')
                      : (AppLocalizations.of(context)?.leaderboardRankInScope(entry.rank, scopeLabel) ?? '#${entry.rank} in $scopeLabel'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                _PointsBar(points: entry.points, color: entry.color),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _TrophyBadge(color: entry.color),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)?.leaderboardLoadFailedTitle ?? 'Failed to load leaderboard',
            style: TextStyle(fontWeight: FontWeight.w800, color: colors.error),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
          ),
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF58CC02).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF58CC02), size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: colors.onSurface)),
            Text(subtitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      ],
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final List<_LeaderboardEntry> entries;
  final bool compact;

  const _LeaderboardList({required this.entries, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF202F36) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: entries.map((entry) {
          return _LeaderboardRow(entry: entry, compact: compact);
        }).toList(),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final _LeaderboardEntry entry;
  final bool compact;

  const _LeaderboardRow({required this.entry, required this.compact});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rowPadding = compact ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    return Container(
      padding: rowPadding,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          _RankBadge(rank: entry.rank, color: entry.color, small: compact),
          const SizedBox(width: 10),
          _AvatarChip(name: entry.name, color: entry.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(fontWeight: FontWeight.w900, color: colors.onSurface),
            ),
          ),
          if (!compact)
            _StreakBadge(streak: entry.streak, color: entry.color, small: true),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context)?.leaderboardPointsKgCo2(entry.points.toStringAsFixed(1)) ??
                '${entry.points.toStringAsFixed(1)} kg CO2',
            style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final Color color;
  final bool small;

  const _RankBadge({required this.rank, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 32.0 : 40.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: small ? 10 : 12),
        ),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  final String name;
  final Color color;

  const _AvatarChip({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
          style: TextStyle(fontWeight: FontWeight.w900, color: color),
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  final Color color;
  final bool small;

  const _StreakBadge({required this.streak, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, size: small ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: small ? 10 : 12),
          ),
        ],
      ),
    );
  }
}

class _TrophyBadge extends StatelessWidget {
  final Color color;

  const _TrophyBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(Icons.emoji_events_rounded, color: color, size: 22),
    );
  }
}

class _PointsBar extends StatelessWidget {
  final double points;
  final Color color;

  const _PointsBar({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (points / 50).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: 8,
        backgroundColor: Colors.black.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}


