// lib/screens/account_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'notification_settings_page.dart';

class AccountPage extends StatefulWidget {
  // 🔴 移除 isLoggedIn 参数，因为我们会自己监听
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const AccountPage({
    super.key,
    required this.onLogin,
    required this.onLogout,
    // 兼容旧代码调用，虽然不用它了
    bool isLoggedIn = false, 
  });

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const String _backendBase = 'https://project-study-bsh.vercel.app';

  bool _hcLoading = false;
  bool _hcConnected = false;
  Map<String, dynamic>? _hcInfo;
  String? _hcError;
  List<Map<String, dynamic>> _hcAppliances = const [];

  @override
  void initState() {
    super.initState();
    // 检查是否有 Deep Link 回调 (HC 授权返回)
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
      // 初始加载一次状态
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshHomeConnectStatus();
      });
    }
  }

  // --- Home Connect 逻辑 (保持不变) ---

  Future<void> _refreshHomeConnectStatus() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    // 🔴 这里的判断改用 currentSession，而不是 widget.isLoggedIn
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _hcConnected = false;
        _hcInfo = null;
        _hcError = null;
        _hcAppliances = const [];
      });
      return;
    }

    setState(() { _hcLoading = true; _hcError = null; });

    try {
      final r = await http.get(
        Uri.parse('$_backendBase/api/hc/status'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200 || data['ok'] != true) throw Exception(data['error'] ?? 'Failed');

      if (!mounted) return;
      setState(() {
        _hcConnected = (data['connected'] == true);
        _hcInfo = (data['info'] is Map<String, dynamic>) ? (data['info'] as Map<String, dynamic>) : null;
        if (!_hcConnected) _hcAppliances = const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _hcConnected = false; _hcInfo = null; _hcError = e.toString(); });
    } finally {
      if (!mounted) return;
      setState(() => _hcLoading = false);
    }
  }

  Future<void> _startHomeConnectBind() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) { widget.onLogin(); return; }

    setState(() { _hcLoading = true; _hcError = null; });

    try {
      final r = await http.post(
        Uri.parse('$_backendBase/api/hc/connect'),
        headers: {'Authorization': 'Bearer ${session.accessToken}', 'Content-Type': 'application/json'},
        body: jsonEncode({"returnTo": "https://bshpwa.vercel.app/#/account?hc=connected"}),
      );
      final data = jsonDecode(r.body);
      if (r.statusCode != 200 || data['ok'] != true) throw Exception(data['error'] ?? 'Failed');
      
      final authorizeUrl = data['authorizeUrl'] as String?;
      if (authorizeUrl == null) throw Exception('No authorizeUrl');
      
      await launchUrl(Uri.parse(authorizeUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hcError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bind failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _hcLoading = false);
    }
  }

  Future<void> _disconnectHomeConnect() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    setState(() { _hcLoading = true; _hcError = null; });
    try {
      final r = await http.delete(
        Uri.parse('$_backendBase/api/hc/disconnect'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      if (r.statusCode != 200) throw Exception('Failed');
      await _refreshHomeConnectStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disconnected')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _hcError = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _hcLoading = false);
    }
  }

  Future<void> _fetchHomeConnectAppliances() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) { widget.onLogin(); return; }
    if (!_hcConnected) return;

    setState(() { _hcLoading = true; _hcError = null; });
    try {
      final r = await http.get(
        Uri.parse('$_backendBase/api/hc/appliances'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200 || data['ok'] != true) throw Exception(data['error']);
      
      final list = (data['homeappliances'] as List?) ?? const [];
      final parsed = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      
      if (!mounted) return;
      setState(() => _hcAppliances = parsed);
      _showApplianceListSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() => _hcError = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _hcLoading = false);
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
                const Text('Simulator Appliances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Text('No appliances found', style: TextStyle(color: Colors.grey))
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final a = items[i];
                        return ListTile(
                          title: Text(a['name'] ?? 'Unknown'),
                          subtitle: Text('ID: ${a['haId']}'),
                          trailing: const Icon(Icons.copy, size: 16),
                          onTap: () {
                            // Copy logic if needed
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================== Build Method ==================

  static const Color _backgroundColor = Color(0xFFF8F9FC);

  @override
  Widget build(BuildContext context) {
    // 🔴 核心修复：使用 StreamBuilder 监听 Supabase Auth 状态
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        final bool loggedIn = session != null;
        final String email = session?.user.email ?? '';

        // 如果状态从未登录变为已登录，自动刷新 HC 状态
        // 注意：这里为了简单，每次 rebuild 可能都会调，但 _refreshHomeConnectStatus 内部有防抖或状态检查最好
        if (loggedIn && !_hcConnected && !_hcLoading) {
           // 可选：在这里静默刷新 HC 状态
           // _refreshHomeConnectStatus(); 
        }

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
            backgroundColor: _backgroundColor,
            elevation: 0,
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // 1. Profile Section
              _buildProfileCard(context, loggedIn, email),

              const SizedBox(height: 32),

              // 2. Integration Section
              _buildSectionTitle(context, 'Integrations'),
              const SizedBox(height: 12),
              _buildHomeConnectCard(context, loggedIn),
              
              const SizedBox(height: 32),

              // 3. General Settings
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
                        MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
                      );
                    },
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.card_giftcard_rounded,
                    iconColor: Colors.purple,
                    title: 'Loyalty Cards',
                    subtitle: 'Connect PAYBACK (Coming soon)',
                    onTap: null,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 4. About
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
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.blueGrey,
                    title: 'Version',
                    trailing: Text('1.0.0 (Beta)', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    onTap: null,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 5. Logout
              if (loggedIn)
                Center(
                  child: TextButton.icon(
                    onPressed: widget.onLogout,
                    icon: Icon(Icons.logout_rounded, size: 20, color: Colors.grey[600]),
                    label: Text('Log Out', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ),
                ),
              
              const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }

  // --- Components ---

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, bool loggedIn, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  loggedIn ? email : 'Sign in to sync',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!loggedIn)
            FilledButton(
              onPressed: widget.onLogin,
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('Log In'),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeConnectCard(BuildContext context, bool loggedIn) {
    final Color brandColor = const Color(0xFF005F87);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: loggedIn && _hcConnected ? brandColor.withOpacity(0.1) : Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            if (!loggedIn) { widget.onLogin(); return; }
            if (_hcConnected) {
              await showModalBottomSheet(
                context: context,
                showDragHandle: true,
                backgroundColor: Colors.white,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(leading: const Icon(Icons.refresh_rounded), title: const Text('Refresh Status'), onTap: () async { Navigator.pop(context); await _refreshHomeConnectStatus(); }),
                      ListTile(leading: const Icon(Icons.kitchen_rounded), title: const Text('View Appliances'), onTap: () async { Navigator.pop(context); await _fetchHomeConnectAppliances(); }),
                      const Divider(),
                      ListTile(leading: Icon(Icons.link_off_rounded, color: Colors.red[400]), title: Text('Disconnect', style: TextStyle(color: Colors.red[700])), onTap: () async { Navigator.pop(context); await _disconnectHomeConnect(); }),
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
                      decoration: BoxDecoration(color: brandColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.home_outlined, color: brandColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BSH Home Connect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                          const SizedBox(height: 2),
                          if (_hcLoading) const Text('Connecting...', style: TextStyle(fontSize: 13, color: Colors.grey))
                          else if (_hcConnected) Text('Active & Synced', style: TextStyle(fontSize: 13, color: Colors.green[600], fontWeight: FontWeight.w600))
                          else const Text('Tap to connect', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (_hcLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else Icon(_hcConnected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, color: _hcConnected ? Colors.green : Colors.grey[300], size: _hcConnected ? 28 : 16),
                  ],
                ),
                if (_hcError != null) Padding(padding: const EdgeInsets.only(top: 16), child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.1))), child: Row(children: [Icon(Icons.error_outline_rounded, size: 16, color: Colors.red[700]), const SizedBox(width: 8), Expanded(child: Text(_hcError!, style: TextStyle(color: Colors.red[900], fontSize: 12)))]))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 辅助组件
class _SettingsContainer extends StatelessWidget {
  final List<Widget> children;
  const _SettingsContainer({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4))]), child: Column(children: children));
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.iconColor, required this.title, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 20)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onTap != null ? Colors.black87 : Colors.grey[400])), if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[500]))]])), if (trailing != null) trailing! else if (onTap != null) Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300])]))));
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.05), indent: 70);
  }
}