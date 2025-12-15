// lib/screens/account_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'notification_settings_page.dart';

class AccountPage extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const AccountPage({
    super.key,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  // 你的 Vercel backend（跑 Home Connect OAuth 的那套）
  static const String _backendBase = 'https://project-study-bsh.vercel.app';

  bool _hcLoading = false;
  bool _hcConnected = false;
  Map<String, dynamic>? _hcInfo;
  String? _hcError;

  // appliances（debug/后续找 oven haId）
  List<Map<String, dynamic>> _hcAppliances = const [];

  @override
  void initState() {
    super.initState();

    // 如果用户从 callback 302 回到前端并带了 ?hc=connected，自动刷新一次状态并提示
    final qp = Uri.base.queryParameters;
    if (qp['hc'] == 'connected') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _refreshHomeConnectStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Home Connect connected ✅')),
        );
      });
    } else {
      // 正常进页面也尝试拉一次状态（仅登录时）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshHomeConnectStatus();
      });
    }
  }

  Future<void> _refreshHomeConnectStatus() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    // 未登录：直接清空状态
    if (!(widget.isLoggedIn && session != null && client.auth.currentUser != null)) {
      if (!mounted) return;
      setState(() {
        _hcConnected = false;
        _hcInfo = null;
        _hcError = null;
        _hcAppliances = const [];
      });
      return;
    }

    setState(() {
      _hcLoading = true;
      _hcError = null;
    });

    try {
      final r = await http.get(
        Uri.parse('$_backendBase/api/hc/status'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200 || data['ok'] != true) {
        throw Exception(data['error'] ?? 'Failed to fetch status');
      }

      if (!mounted) return;
      setState(() {
        _hcConnected = (data['connected'] == true);
        _hcInfo = (data['info'] is Map<String, dynamic>) ? (data['info'] as Map<String, dynamic>) : null;
        if (!_hcConnected) _hcAppliances = const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hcConnected = false;
        _hcInfo = null;
        _hcAppliances = const [];
        _hcError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _hcLoading = false;
      });
    }
  }

  Future<void> _startHomeConnectBind() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;

    if (!(widget.isLoggedIn && session != null && user != null)) {
      widget.onLogin();
      return;
    }

    setState(() {
      _hcLoading = true;
      _hcError = null;
    });

    try {
      final r = await http.post(
        Uri.parse('$_backendBase/api/hc/connect'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "returnTo": "https://bshpwa.vercel.app/#/account?hc=connected",
        }),
      );

      // ✅ 关键：无论成功失败都把原始 body 打出来
      debugPrint('[HC] /api/hc/connect status=${r.statusCode}');
      debugPrint('[HC] /api/hc/connect body=${r.body}');

      // 尝试解析 JSON（失败也不要直接崩）
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(r.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        data = null;
      }

      // 非 200：优先把后端返回的 step/error/stack 展示出来
      if (r.statusCode != 200) {
        final step = data?['step'];
        final err = data?['error'] ?? r.body;
        final stack = data?['stack'];

        throw Exception(
          [
            'Backend ${r.statusCode}',
            if (step != null) 'step=$step',
            'error=$err',
            if (stack != null) 'stack=$stack',
          ].join(' | '),
        );
      }

      // 200 但 ok != true
      if (data == null || data['ok'] != true) {
        throw Exception('Invalid response: ${r.body}');
      }

      final authorizeUrl = data['authorizeUrl'] as String?;
      if (authorizeUrl == null || authorizeUrl.isEmpty) {
        throw Exception('Missing authorizeUrl. Full response: ${r.body}');
      }

      final uri = Uri.parse(authorizeUrl);

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw Exception('Could not open Home Connect authorization page');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hcError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Home Connect bind failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _hcLoading = false;
      });
    }
  }

  Future<void> _disconnectHomeConnect() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;

    if (!(widget.isLoggedIn && session != null && user != null)) return;

    setState(() {
      _hcLoading = true;
      _hcError = null;
    });

    try {
      final r = await http.delete(
        Uri.parse('$_backendBase/api/hc/disconnect'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200 || data['ok'] != true) {
        throw Exception(data['error'] ?? 'Failed to disconnect');
      }

      await _refreshHomeConnectStatus();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home Connect disconnected')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hcError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _hcLoading = false;
      });
    }
  }

  Future<void> _fetchHomeConnectAppliances() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;

    if (!(widget.isLoggedIn && session != null && user != null)) {
      widget.onLogin();
      return;
    }
    if (!_hcConnected) {
      setState(() => _hcError = 'Home Connect is not connected yet.');
      return;
    }

    setState(() {
      _hcLoading = true;
      _hcError = null;
    });

    try {
      final r = await http.get(
        Uri.parse('$_backendBase/api/hc/appliances'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      debugPrint('[HC] /api/hc/appliances status=${r.statusCode}');
      debugPrint('[HC] /api/hc/appliances body=${r.body}');

      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200 || data['ok'] != true) {
        throw Exception(data['error'] ?? 'Failed to fetch appliances');
      }

      final list = (data['homeappliances'] as List?) ?? const [];
      final parsed = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      if (!mounted) return;
      setState(() {
        _hcAppliances = parsed;
      });

      if (!mounted) return;
      _showApplianceListSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hcError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fetch appliances failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _hcLoading = false;
      });
    }
  }

  void _showApplianceListSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final items = _hcAppliances;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Home Connect appliances',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    Text(
                      '${items.length}',
                      style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No appliances returned by simulator.',
                      style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final a = items[i];
                        final name = (a['name'] ?? a['brand'] ?? a['type'] ?? 'Appliance').toString();
                        final type = (a['type'] ?? a['encryption'] ?? '').toString();
                        final haId = (a['haId'] ?? a['id'] ?? '').toString();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'type: ${type.isEmpty ? '-' : type}\nhaId: ${haId.isEmpty ? '-' : haId}',
                            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, height: 1.2),
                          ),
                          trailing: haId.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    // 不引入 clipboard 依赖，先用 snackbar 提示你自己复制/截图
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('haId: $haId')),
                                    );
                                  },
                                ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    label: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = const Color(0xFFF6F8FA);

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    final bool loggedIn = widget.isLoggedIn && user != null;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Stack(
        children: [
          // 科技感背景装饰
          Positioned(
            right: -90,
            top: -120,
            child: _GlowOrb(
              size: 260,
              color: scheme.primary.withOpacity(0.18),
            ),
          ),
          Positioned(
            left: -90,
            bottom: -120,
            child: _GlowOrb(
              size: 280,
              color: scheme.secondary.withOpacity(0.14),
            ),
          ),

          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            children: [
              // 顶部：账号状态（更“产品化”）
              _GlassCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: loggedIn
                      ? _buildLoggedInHeader(context, email)
                      : _buildLoggedOutHeader(context),
                ),
              ),

              const SizedBox(height: 18),

              _SectionHeader(
                title: 'Partners',
                subtitle: 'Appliances and rewards (coming soon)',
                icon: Icons.hub_outlined,
                color: scheme.primary,
              ),
              const SizedBox(height: 10),

              _GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const _SquareIconStatic(
                        icon: Icons.kitchen_outlined,
                        color: Color(0xFF0A6BA8),
                      ),
                      title: const Text(
                        'BSH Home Connect',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        !loggedIn
                            ? 'Log in to connect your Home Connect account'
                            : _hcLoading
                                ? 'Checking connection...'
                                : _hcConnected
                                    ? 'Connected ✅'
                                    : 'Connect to control appliances (simulator)',
                      ),
                      trailing: _hcLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_hcConnected ? Icons.check_circle : Icons.chevron_right),
                      enabled: true,
                      onTap: () async {
                        if (!loggedIn) {
                          widget.onLogin();
                          return;
                        }
                        if (_hcConnected) {
                          await showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            builder: (_) {
                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.refresh),
                                      title: const Text('Refresh status'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await _refreshHomeConnectStatus();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.list_alt),
                                      title: const Text('Fetch appliances (get oven haId)'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await _fetchHomeConnectAppliances();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.link_off),
                                      title: const Text('Disconnect'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await _disconnectHomeConnect();
                                      },
                                    ),
                                    if (_hcInfo != null)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Text(
                                          'Host: ${_hcInfo?['hc_host'] ?? '-'}\n'
                                          'Scope: ${_hcInfo?['scope'] ?? '-'}\n'
                                          'Expires: ${_hcInfo?['expires_at'] ?? '-'}\n'
                                          'Updated: ${_hcInfo?['updated_at'] ?? '-'}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        } else {
                          await _startHomeConnectBind();
                        }
                      },
                    ),
                    const _SoftDividerStatic(),
                    const ListTile(
                      leading: _SquareIconStatic(
                        icon: Icons.card_giftcard_outlined,
                        color: Color(0xFF3B6AF0),
                      ),
                      title: Text(
                        'PAYBACK / loyalty cards',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('Explore rewards for reducing food waste'),
                      trailing: Icon(Icons.chevron_right),
                      enabled: false,
                    ),
                    if (_hcError != null) ...[
                      const _SoftDividerStatic(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Text(
                          _hcError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _SectionHeader(
                title: 'Preferences',
                subtitle: 'Personalize the experience',
                icon: Icons.tune_rounded,
                color: scheme.secondary,
              ),
              const SizedBox(height: 10),

              _GlassCard(
                child: Column(
                  children: [
                    _SettingTile(
                      title: 'Notifications',
                      subtitle: 'Reminders for items close to expiry',
                      icon: Icons.notifications_none_rounded,
                      color: scheme.primary,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationSettingsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _SectionHeader(
                title: 'Privacy & legal',
                subtitle: 'Transparency and terms',
                icon: Icons.verified_outlined,
                color: Colors.grey.shade800,
              ),
              const SizedBox(height: 10),

              _GlassCard(
                child: Column(
                  children: const [
                    ListTile(
                      leading: _SquareIconStatic(
                        icon: Icons.insights_outlined,
                        color: Color(0xFF55606A),
                      ),
                      title: Text(
                        'App data usage',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('How we use your feedback and behaviour'),
                      enabled: false,
                    ),
                    _SoftDividerStatic(),
                    ListTile(
                      leading: _SquareIconStatic(
                        icon: Icons.description_outlined,
                        color: Color(0xFF55606A),
                      ),
                      title: Text(
                        'Legal information',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('Terms of use, privacy policy'),
                      enabled: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Center(
                child: SizedBox(
                  width: 280,
                  height: 48,
                  child: loggedIn
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.logout),
                          onPressed: widget.onLogout,
                          label: const Text(
                            'Log out',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                      : _GradientButton(
                          text: 'Log in / Sign up',
                          onPressed: widget.onLogin,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedOutHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: scheme.primary.withOpacity(0.10),
            border: Border.all(color: scheme.primary.withOpacity(0.16)),
          ),
          child: Icon(Icons.person_outline_rounded, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start using Smart Food Home',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[900],
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Log in to enable AI features!',
                style: TextStyle(
                  color: Colors.grey[700],
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.tonal(
                  onPressed: widget.onLogin,
                  child: const Text(
                    'Log in / Sign up',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedInHeader(BuildContext context, String email) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.green.withOpacity(0.10),
            border: Border.all(color: Colors.green.withOpacity(0.16)),
          ),
          child: Icon(Icons.verified_user_outlined, color: Colors.green.shade700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logged in',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[900],
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===================== UI components (no logic changes) =====================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SquareIcon(icon: icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[900],
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.92),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: _GlowOrb(
                size: 140,
                color: scheme.primary.withOpacity(0.10),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget trailing;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            _SquareIcon(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SquareIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

// 用于 const ListTile（不能用 Theme.of）
class _SquareIconStatic extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SquareIconStatic({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String text;
  final Color color;

  const _PillChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _GradientButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            scheme.primary.withOpacity(0.78),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.20),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

class _SoftDividerStatic extends StatelessWidget {
  const _SoftDividerStatic();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Color(0x11000000));
  }
}
