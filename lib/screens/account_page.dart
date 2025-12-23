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
  // 你的 Vercel backend
  static const String _backendBase = 'https://project-study-bsh.vercel.app';

  bool _hcLoading = false;
  bool _hcConnected = false;
  Map<String, dynamic>? _hcInfo;
  String? _hcError;

  // appliances
  List<Map<String, dynamic>> _hcAppliances = const [];

  // ================== 逻辑部分保持不变 ==================

  @override
  void initState() {
    super.initState();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshHomeConnectStatus();
      });
    }
  }

  Future<void> _refreshHomeConnectStatus() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

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

      debugPrint('[HC] /api/hc/connect status=${r.statusCode}');
      debugPrint('[HC] /api/hc/connect body=${r.body}');

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(r.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        data = null;
      }

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
      backgroundColor: Colors.white,
      builder: (_) {
        final items = _hcAppliances;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.kitchen_rounded, color: Color(0xFF005F87)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Simulator Appliances',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        Icon(Icons.device_unknown_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'No appliances found in simulator.',
                          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final a = items[i];
                        final name = (a['name'] ?? a['brand'] ?? a['type'] ?? 'Appliance').toString();
                        final type = (a['type'] ?? a['encryption'] ?? '').toString();
                        final haId = (a['haId'] ?? a['id'] ?? '').toString();

                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'Type: $type\nID: $haId',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                            ),
                            trailing: haId.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 20),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('ID Copied: $haId')),
                                      );
                                    },
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================== UI 构建部分 ==================

  // 统一的背景色，保持和其他页面一致
  static const Color _backgroundColor = Color(0xFFF8F9FC);

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    final bool loggedIn = widget.isLoggedIn && user != null;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 1. Profile Section (Level 1)
          _buildProfileCard(context, loggedIn, email),

          const SizedBox(height: 32),

          // 2. Integration Section (Level 2 - High Priority)
          _buildSectionTitle(context, 'Integrations'),
          const SizedBox(height: 12),
          _buildHomeConnectCard(context, loggedIn),
          
          const SizedBox(height: 32),

          // 3. General Settings (Level 3)
          _buildSectionTitle(context, 'Preferences'),
          const SizedBox(height: 12),
          _SettingsContainer(
            children: [
              _SettingsTile(
                icon: Icons.notifications_rounded,
                iconColor: Colors.orange,
                title: 'Notifications',
                subtitle: 'Expiry alerts & reminders',
                onTap: () {
                   Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsPage(),
                    ),
                  );
                },
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.card_giftcard_rounded,
                iconColor: Colors.purple,
                title: 'Loyalty Cards',
                subtitle: 'Connect PAYBACK (Coming soon)',
                onTap: null, // Disabled
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 4. Legal & Privacy
          _buildSectionTitle(context, 'About'),
          const SizedBox(height: 12),
          _SettingsContainer(
            children: [
              _SettingsTile(
                icon: Icons.privacy_tip_rounded,
                iconColor: Colors.blueGrey,
                title: 'Privacy Policy',
                onTap: null,
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.description_rounded,
                iconColor: Colors.blueGrey,
                title: 'Terms of Service',
                onTap: null,
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: Colors.blueGrey,
                title: 'Version',
                trailing: Text(
                  '1.0.0 (Beta)',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                onTap: null,
              ),
            ],
          ),

          const SizedBox(height: 40),

          // 5. Logout Action
          if (loggedIn)
            Center(
              child: TextButton.icon(
                onPressed: widget.onLogout,
                icon: Icon(Icons.logout_rounded, size: 20, color: Colors.grey[600]),
                label: Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- Components ---

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, bool loggedIn, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: loggedIn ? const Color(0xFFE3F2FD) : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              loggedIn ? Icons.person_rounded : Icons.person_off_rounded,
              color: loggedIn ? const Color(0xFF1565C0) : Colors.grey[400],
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loggedIn ? 'Welcome back' : 'Guest Account',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loggedIn ? email : 'Sign in to sync',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!loggedIn)
            FilledButton(
              onPressed: widget.onLogin,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Log In'),
            ),
        ],
      ),
    );
  }

  // 专门优化的 Home Connect 卡片，因为它是核心功能
  Widget _buildHomeConnectCard(BuildContext context, bool loggedIn) {
    final Color brandColor = const Color(0xFF005F87); // BSH Blue

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: loggedIn && _hcConnected ? brandColor.withOpacity(0.1) : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            if (!loggedIn) {
              widget.onLogin();
              return;
            }
            if (_hcConnected) {
              // 显示管理菜单
              await showModalBottomSheet(
                context: context,
                showDragHandle: true,
                backgroundColor: Colors.white,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.refresh_rounded),
                        title: const Text('Refresh Status'),
                        onTap: () async {
                          Navigator.pop(context);
                          await _refreshHomeConnectStatus();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.kitchen_rounded),
                        title: const Text('View Appliances & IDs'),
                        subtitle: const Text('For simulation & debugging'),
                        onTap: () async {
                          Navigator.pop(context);
                          await _fetchHomeConnectAppliances();
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(Icons.link_off_rounded, color: Colors.red[400]),
                        title: Text('Disconnect', style: TextStyle(color: Colors.red[700])),
                        onTap: () async {
                          Navigator.pop(context);
                          await _disconnectHomeConnect();
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            } else {
              await _startHomeConnectBind();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: brandColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.home_outlined, color: brandColor, size: 24), // 使用更相关的图标
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BSH Home Connect',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_hcLoading)
                            const Text(
                              'Connecting...',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            )
                          else if (_hcConnected)
                             Text(
                              'Active & Synced',
                              style: TextStyle(fontSize: 13, color: Colors.green[600], fontWeight: FontWeight.w600),
                            )
                          else
                            const Text(
                              'Tap to connect simulator',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    if (_hcLoading)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(
                        _hcConnected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                        color: _hcConnected ? Colors.green : Colors.grey[300],
                        size: _hcConnected ? 28 : 16,
                      ),
                  ],
                ),
                // 错误信息展示
                if (_hcError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 16, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _hcError!,
                              style: TextStyle(color: Colors.red[900], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // 连接后的详细信息 (Optional)
                if (_hcConnected && _hcInfo != null)
                   Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_done_outlined, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          'Host: ${_hcInfo?['hc_host'] ?? 'Unknown'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 统一的圆角容器，用于包裹列表
class _SettingsContainer extends StatelessWidget {
  final List<Widget> children;
  const _SettingsContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24), // 确保水波纹不溢出
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: onTap != null ? Colors.black87 : Colors.grey[400],
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.05), indent: 70);
  }
}