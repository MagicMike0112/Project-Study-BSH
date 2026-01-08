// lib/screens/account_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
// 🟢 确保 pubspec.yaml 中有 url_launcher
import 'package:url_launcher/url_launcher.dart';

import '../repositories/inventory_repository.dart';
import 'family_page.dart';
import 'notification_settings_page.dart';
import 'login_page.dart';
// 🟢 引入我们的原生 Toast 封装
import '../utils/bsh_toast.dart';

class AccountPage extends StatefulWidget {
  final InventoryRepository repo;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const AccountPage({
    super.key,
    required this.repo,
    required this.onLogin,
    required this.onLogout,
    bool isLoggedIn = false,
  });

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const String _backendBase = 'https://project-study-bsh.vercel.app';
  static const Color _primaryColor = Color(0xFF004A77);

  bool _hcLoading = false;
  bool _hcConnected = false;
  Map<String, dynamic>? _hcInfo;
  String? _hcError;
  List<Map<String, dynamic>> _hcAppliances = const [];

  bool _studentMode = false;

  @override
  void initState() {
    super.initState();
    _initStudentMode();

    // 检查 Home Connect 回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final qp = Uri.base.queryParameters;
      if (qp['hc'] == 'connected') {
        _refreshHomeConnectStatus().then((_) {
          if (mounted) {
            BSHToast.show(context, title: 'Home Connect Linked ✅', type: BSHToastType.success);
          }
        });
      } else {
        _refreshHomeConnectStatus();
      }
    });
  }

  void _initStudentMode() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      if (meta.containsKey('student_mode')) {
        setState(() {
          _studentMode = meta['student_mode'] == true;
        });
      } else {
        final ageVal = meta['age'];
        if (ageVal != null) {
          final age = int.tryParse(ageVal.toString()) ?? 25;
          if (age < 24) {
            setState(() => _studentMode = true);
          }
        }
      }
    }
  }

  Future<void> _toggleStudentMode(bool value) async {
    setState(() => _studentMode = value);
    HapticFeedback.selectionClick();
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // 兼容写法：直接传 Map
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'student_mode': value}),
        );
      }
    } catch (e) {
      debugPrint('Failed to save student mode preference: $e');
    }
  }

  // --- Home Connect Logic ---

  Future<void> _refreshHomeConnectStatus() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null) {
      if (mounted) {
        setState(() {
          _hcConnected = false;
          _hcInfo = null;
          _hcError = null;
          _hcAppliances = const [];
        });
      }
      return;
    }

    if (mounted) setState(() { _hcLoading = true; _hcError = null; });

    try {
      final r = await http.get(
        Uri.parse('$_backendBase/api/hc?action=status'), 
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200 || data['ok'] != true) throw Exception(data['error'] ?? 'Failed');

      if (mounted) {
        setState(() {
          _hcConnected = (data['connected'] == true);
          _hcInfo = (data['info'] is Map<String, dynamic>) ? (data['info'] as Map<String, dynamic>) : null;
          if (!_hcConnected) _hcAppliances = const [];
        });
      }
    } catch (e) {
      if (mounted) setState(() { _hcConnected = false; _hcInfo = null; _hcError = e.toString(); });
    } finally {
      if (mounted) setState(() => _hcLoading = false);
    }
  }

  Future<void> _startHomeConnectBind() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) { _handleLogin(); return; } 

    if (mounted) setState(() { _hcLoading = true; _hcError = null; });

    try {
      final r = await http.post(
        Uri.parse('$_backendBase/api/hc?action=connect'),
        headers: {'Authorization': 'Bearer ${session.accessToken}', 'Content-Type': 'application/json'},
        body: jsonEncode({"returnTo": "https://bshpwa.vercel.app/#/account?hc=connected"}),
      );
      final data = jsonDecode(r.body);
      if (r.statusCode != 200 || data['ok'] != true) throw Exception(data['error'] ?? 'Failed');
      
      final authorizeUrl = data['authorizeUrl'] as String?;
      if (authorizeUrl == null) throw Exception('No authorizeUrl');
      
      await launchUrl(Uri.parse(authorizeUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        setState(() => _hcError = e.toString());
        BSHToast.show(context, title: 'Connection Failed', type: BSHToastType.error);
      }
    } finally {
      if (mounted) setState(() => _hcLoading = false);
    }
  }

  Future<void> _disconnectHomeConnect() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    if (mounted) setState(() { _hcLoading = true; _hcError = null; });
    try {
      final r = await http.delete(
        Uri.parse('$_backendBase/api/hc?action=disconnect'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      if (r.statusCode != 200) throw Exception('Failed');
      await _refreshHomeConnectStatus();
      if (mounted) BSHToast.show(context, title: 'Disconnected', type: BSHToastType.info);
    } catch (e) {
      if (mounted) setState(() => _hcError = e.toString());
    } finally {
      if (mounted) setState(() => _hcLoading = false);
    }
  }

  Future<void> _fetchHomeConnectAppliances() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) { _handleLogin(); return; }
    if (!_hcConnected) return;

    if (mounted) setState(() { _hcLoading = true; _hcError = null; });
    try {
      final r = await http.get(
        Uri.parse('$_backendBase/api/hc?action=appliances'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200 || data['ok'] != true) throw Exception(data['error']);
      
      final list = (data['homeappliances'] as List?) ?? const [];
      final parsed = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      
      if (mounted) setState(() => _hcAppliances = parsed);
      _showApplianceListSheet();
    } catch (e) {
      if (mounted) setState(() => _hcError = e.toString());
    } finally {
      if (mounted) setState(() => _hcLoading = false);
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
                            Clipboard.setData(ClipboardData(text: a['haId'].toString()));
                            BSHToast.show(context, title: 'ID Copied', type: BSHToastType.info);
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

  void _handleLogin() {
    HapticFeedback.mediumImpact();
    widget.onLogin();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage(allowSkip: false)),
    );
  }

  // ================== Build Method ==================

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<InventoryRepository>(context);
    final isSenior = repo.isSeniorMode;

    // 🟢 Dynamic Theme Values
    final bgColor = isSenior ? Colors.white : const Color(0xFFF8F9FC);
    final sectionTitleColor = isSenior ? Colors.black : Colors.grey[500];
    final sectionTitleSize = isSenior ? 16.0 : 12.0;

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        final bool loggedIn = session != null;
        final String email = session?.user.email ?? '';
        final String name = session?.user.userMetadata?['full_name'] ?? 'User';

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              isSenior ? 'My Account' : 'Account', 
              style: TextStyle(
                fontWeight: FontWeight.w700, 
                color: Colors.black87,
                fontSize: isSenior ? 26 : 20, 
              )
            ),
            backgroundColor: bgColor,
            elevation: 0,
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              _buildProfileCard(context, loggedIn, name, email, isSenior),
              const SizedBox(height: 32),
              
              if (loggedIn) ...[
                _buildSectionTitle('Household', isSenior, sectionTitleColor!, sectionTitleSize),
                const SizedBox(height: 12),
                _buildFamilyCard(context, isSenior),
                const SizedBox(height: 32),
              ],
              
              _buildSectionTitle('Integrations', isSenior, sectionTitleColor!, sectionTitleSize),
              const SizedBox(height: 12),
              _buildHomeConnectCard(context, loggedIn, isSenior),
              
              const SizedBox(height: 32),
              
              _buildSectionTitle('Preferences', isSenior, sectionTitleColor!, sectionTitleSize),
              const SizedBox(height: 12),
              _SettingsContainer(
                isSenior: isSenior,
                children: [
                  _SettingsTile(
                    isSenior: isSenior,
                    icon: Icons.notifications_rounded,
                    iconColor: Colors.orange,
                    title: 'Notifications',
                    subtitle: isSenior ? null : 'Expiry alerts & reminders',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
                      );
                    },
                  ),
                  _Divider(isSenior: isSenior),
                  
                  // 🟢 Senior Mode Switch
                  _SettingsTile(
                    isSenior: isSenior,
                    icon: Icons.accessibility_new_rounded,
                    iconColor: Colors.teal,
                    title: isSenior ? 'Senior Mode (On)' : 'Senior Mode',
                    subtitle: isSenior ? 'Large Text & High Contrast' : 'Large text & high contrast',
                    trailing: Switch.adaptive(
                      value: isSenior,
                      activeColor: _primaryColor,
                      onChanged: (val) {
                        HapticFeedback.mediumImpact();
                        repo.toggleSeniorMode(val);
                        BSHToast.show(
                          context, 
                          title: val ? "Senior Mode Enabled" : "Standard Mode Restored",
                          type: BSHToastType.info
                        );
                      },
                    ),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      repo.toggleSeniorMode(!isSenior);
                    },
                  ),
                  
                  _Divider(isSenior: isSenior),

                  _SettingsTile(
                    isSenior: isSenior,
                    icon: Icons.school_rounded,
                    iconColor: Colors.indigo,
                    title: 'Student Mode',
                    subtitle: isSenior ? null : 'Budget-friendly recipes & tips 🎓',
                    trailing: Switch.adaptive(
                      value: _studentMode,
                      activeColor: _primaryColor,
                      onChanged: _toggleStudentMode,
                    ),
                    onTap: () => _toggleStudentMode(!_studentMode),
                  ),
                  
                  _Divider(isSenior: isSenior),
                  
                  const _SettingsTile(
                    isSenior: false, // Loyalty cards usually standard UI
                    icon: Icons.card_giftcard_rounded,
                    iconColor: Colors.purple,
                    title: 'Loyalty Cards',
                    subtitle: 'Connect PAYBACK (Coming soon)',
                    onTap: null,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              _buildSectionTitle('About', isSenior, sectionTitleColor!, sectionTitleSize),
              const SizedBox(height: 12),
              _SettingsContainer(
                isSenior: isSenior,
                children: [
                  const _SettingsTile(
                    isSenior: false,
                    icon: Icons.privacy_tip_rounded,
                    iconColor: Colors.blueGrey,
                    title: 'Privacy Policy',
                    onTap: null,
                  ),
                  _Divider(isSenior: isSenior),
                  _SettingsTile(
                    isSenior: isSenior,
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.blueGrey,
                    title: 'Version',
                    trailing: Text('1.0.0 (Beta)', style: TextStyle(color: Colors.grey[500], fontSize: isSenior ? 16 : 13)),
                    onTap: null,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              if (loggedIn)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      widget.onLogout();
                    },
                    icon: Icon(Icons.logout_rounded, size: isSenior ? 28 : 20, color: Colors.grey[600]),
                    label: Text(
                      'Sign Out', 
                      style: TextStyle(
                        color: Colors.grey[600], 
                        fontWeight: FontWeight.w600,
                        fontSize: isSenior ? 20 : 14
                      )
                    ),
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

  Widget _buildSectionTitle(String title, bool isSenior, Color color, double size) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        isSenior ? title : title.toUpperCase(),
        style: TextStyle(
          fontSize: size, 
          fontWeight: FontWeight.w700, 
          color: color, 
          letterSpacing: isSenior ? 0 : 1.2
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, bool loggedIn, String name, String email, bool isSenior) {
    return Container(
      padding: EdgeInsets.all(isSenior ? 24 : 20),
      decoration: BoxDecoration(
        color: isSenior ? Colors.yellow.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isSenior ? Border.all(color: Colors.black, width: 2) : null,
        boxShadow: isSenior ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: isSenior ? 70 : 60, height: isSenior ? 70 : 60,
            decoration: BoxDecoration(
              color: loggedIn ? const Color(0xFFE3F2FD) : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
              border: isSenior ? Border.all(color: Colors.black) : null,
            ),
            child: Icon(
              loggedIn ? Icons.person_rounded : Icons.person_off_rounded,
              color: loggedIn ? const Color(0xFF1565C0) : Colors.grey[400],
              size: isSenior ? 40 : 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loggedIn ? 'Hello, $name' : 'Guest Account',
                  style: TextStyle(fontSize: isSenior ? 22 : 16, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  loggedIn ? email : 'Sign in to sync your data',
                  style: TextStyle(fontSize: isSenior ? 16 : 13, color: isSenior ? Colors.black87 : Colors.grey[600]),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!loggedIn)
            FilledButton(
              onPressed: _handleLogin,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), 
                padding: EdgeInsets.symmetric(horizontal: isSenior ? 24 : 16, vertical: isSenior ? 16 : 0)
              ),
              child: Text('Log In', style: TextStyle(fontSize: isSenior ? 18 : 14)),
            ),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context, bool isSenior) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyPage(repo: widget.repo))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isSenior ? Border.all(color: Colors.black, width: 2) : null,
          boxShadow: isSenior ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16)],
        ),
        child: Row(
          children: [
            const Icon(Icons.home_rounded, color: _primaryColor, size: 30),
            const SizedBox(width: 16),
            Expanded(child: Text(widget.repo.currentFamilyName, style: TextStyle(fontSize: isSenior ? 20 : 16, fontWeight: FontWeight.bold))),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeConnectCard(BuildContext context, bool loggedIn, bool isSenior) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isSenior 
            ? Border.all(color: Colors.black, width: 2) 
            : Border.all(color: loggedIn && _hcConnected ? _primaryColor.withOpacity(0.1) : Colors.transparent),
        boxShadow: isSenior ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            if (!loggedIn) { _handleLogin(); return; } 
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
            padding: EdgeInsets.all(isSenior ? 24 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(12),
                        border: isSenior ? Border.all(color: Colors.black) : null,
                      ),
                      child: Icon(Icons.power_settings_new_rounded, color: _primaryColor, size: isSenior ? 32 : 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Home Connect', style: TextStyle(fontSize: isSenior ? 20 : 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                          const SizedBox(height: 2),
                          if (_hcLoading) const Text('Connecting...', style: TextStyle(fontSize: 13, color: Colors.grey))
                          else if (_hcConnected) Text('Active & Synced', style: TextStyle(fontSize: isSenior ? 16 : 13, color: Colors.green[600], fontWeight: FontWeight.w600))
                          else Text('Tap to connect', style: TextStyle(fontSize: isSenior ? 16 : 13, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (_hcLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else Icon(_hcConnected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, color: _hcConnected ? Colors.green : (isSenior ? Colors.black : Colors.grey[300]), size: _hcConnected ? 28 : 16),
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

class _SettingsContainer extends StatelessWidget {
  final List<Widget> children;
  final bool isSenior;
  const _SettingsContainer({required this.children, required this.isSenior});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        border: isSenior ? Border.all(color: Colors.black, width: 2) : null,
        boxShadow: isSenior ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4))]
      ), 
      child: Column(children: children)
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isSenior;

  const _SettingsTile({required this.icon, this.iconColor, required this.title, this.subtitle, this.trailing, this.onTap, this.isSenior = false});
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10), 
        decoration: BoxDecoration(
          color: (iconColor ?? Colors.grey).withOpacity(0.1), 
          borderRadius: BorderRadius.circular(12),
          border: isSenior ? Border.all(color: Colors.black) : null,
        ), 
        child: Icon(icon, color: iconColor, size: isSenior ? 28 : 20)
      ), 
      title: Text(title, style: TextStyle(fontSize: isSenior ? 18 : 15, fontWeight: FontWeight.w600)), 
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: isSenior ? 14 : 12)) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: isSenior ? 12 : 8),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isSenior;
  const _Divider({required this.isSenior});
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: isSenior ? 2 : 1, color: isSenior ? Colors.black : Colors.grey.withOpacity(0.05), indent: 70);
  }
}