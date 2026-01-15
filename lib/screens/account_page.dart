// lib/screens/account_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../repositories/inventory_repository.dart';
import 'family_page.dart';
import 'notification_settings_page.dart';
import 'login_page.dart';
import '../utils/bsh_toast.dart';
import '../utils/theme_controller.dart';

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
      backgroundColor: Theme.of(context).cardColor,
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
                  Text(
                    'No appliances found',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  )
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

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow system';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemePicker(ThemeController themeController) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeController.themeMode,
                onChanged: (val) {
                  if (val != null) themeController.setThemeMode(val);
                  Navigator.pop(ctx);
                },
                title: const Text('Follow system'),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeController.themeMode,
                onChanged: (val) {
                  if (val != null) themeController.setThemeMode(val);
                  Navigator.pop(ctx);
                },
                title: const Text('Light'),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeController.themeMode,
                onChanged: (val) {
                  if (val != null) themeController.setThemeMode(val);
                  Navigator.pop(ctx);
                },
                title: const Text('Dark'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ================== Build Method ==================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bgColor = theme.scaffoldBackgroundColor;
    final sectionTitleColor = colors.onSurface.withOpacity(0.55);
    const sectionTitleSize = 12.0;

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        final bool loggedIn = session != null;
        final String email = session?.user.email ?? '';
        final String name = session?.user.userMetadata?['full_name'] ?? 'User';
        final themeController = context.watch<ThemeController>();

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              'Account',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                fontSize: 20,
              ),
            ),
            backgroundColor: bgColor,
            elevation: 0,
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              _buildProfileCard(context, loggedIn, name, email),
              const SizedBox(height: 32),
              
              if (loggedIn) ...[
                _buildSectionTitle('Household', sectionTitleColor!, sectionTitleSize),
                const SizedBox(height: 12),
                _buildFamilyCard(context),
                const SizedBox(height: 32),
              ],
              
              _buildSectionTitle('Integrations', sectionTitleColor!, sectionTitleSize),
              const SizedBox(height: 12),
              _buildHomeConnectCard(context, loggedIn),
              
              const SizedBox(height: 32),
              
              _buildSectionTitle('Preferences', sectionTitleColor!, sectionTitleSize),
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
                  const _Divider(),

                  _SettingsTile(
                    icon: Icons.dark_mode_rounded,
                    iconColor: Colors.blueGrey,
                    title: 'Night Mode',
                    subtitle: _themeLabel(themeController.themeMode),
                    trailing: Text(
                      _themeLabel(themeController.themeMode),
                      style: TextStyle(color: colors.onSurface.withOpacity(0.5), fontSize: 12),
                    ),
                    onTap: () => _showThemePicker(themeController),
                  ),

                  const _Divider(),

                  _SettingsTile(
                    icon: Icons.school_rounded,
                    iconColor: Colors.indigo,
                    title: 'Student Mode',
                    subtitle: 'Budget-friendly recipes & tips 🎓',
                    trailing: Switch.adaptive(
                      value: _studentMode,
                      activeColor: _primaryColor,
                      onChanged: _toggleStudentMode,
                    ),
                    onTap: () => _toggleStudentMode(!_studentMode),
                  ),
                  
                  const _Divider(),
                  
                  const _SettingsTile(
                    icon: Icons.card_giftcard_rounded,
                    iconColor: Colors.purple,
                    title: 'Loyalty Cards',
                    subtitle: 'Connect PAYBACK (Coming soon)',
                    onTap: null,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              _buildSectionTitle('About', sectionTitleColor!, sectionTitleSize),
              const SizedBox(height: 12),
              _SettingsContainer(
                children: [
                  const _SettingsTile(
                    icon: Icons.privacy_tip_rounded,
                    iconColor: Colors.blueGrey,
                    title: 'Privacy Policy',
                    onTap: null,
                  ),
                  const _Divider(),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.blueGrey,
                    title: 'Version',
                    trailing: Text(
                      '1.0.0 (Beta)',
                      style: TextStyle(color: colors.onSurface.withOpacity(0.5), fontSize: 13),
                    ),
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
                    icon: Icon(Icons.logout_rounded, size: 20, color: colors.onSurface.withOpacity(0.6)),
                    label: Text(
                      'Sign Out', 
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                        fontSize: 14
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

  Widget _buildSectionTitle(String title, Color color, double size) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: size, 
          fontWeight: FontWeight.w700, 
          color: color, 
          letterSpacing: 1.2
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, bool loggedIn, String name, String email) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: loggedIn
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE3F2FD))
                  : (isDark ? const Color(0xFF2A2F36) : const Color(0xFFF5F5F5)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              loggedIn ? Icons.person_rounded : Icons.person_off_rounded,
              color: loggedIn ? const Color(0xFF1565C0) : colors.onSurface.withOpacity(0.4),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(
                    loggedIn ? 'Hello, $name' : 'Guest Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loggedIn ? email : 'Sign in to sync your data',
                    style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.6)),
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
                padding: const EdgeInsets.symmetric(horizontal: 16)
              ),
              child: const Text('Log In', style: TextStyle(fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyPage(repo: widget.repo))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 16,
            )
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.home_rounded, color: _primaryColor, size: 30),
            const SizedBox(width: 16),
            Expanded(child: Text(widget.repo.currentFamilyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeConnectCard(BuildContext context, bool loggedIn) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: loggedIn && _hcConnected ? _primaryColor.withOpacity(0.1) : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
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
                backgroundColor: Theme.of(context).cardColor,
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
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.power_settings_new_rounded, color: _primaryColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Home Connect',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
                          ),
                          const SizedBox(height: 2),
                          if (_hcLoading)
                            Text(
                              'Connecting...',
                              style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.5)),
                            )
                          else if (_hcConnected)
                            Text(
                              'Active & Synced',
                              style: TextStyle(fontSize: 13, color: Colors.green[600], fontWeight: FontWeight.w600),
                            )
                          else
                            Text(
                              'Tap to connect',
                              style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.5)),
                            ),
                        ],
                      ),
                    ),
                    if (_hcLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else Icon(
                      _hcConnected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                      color: _hcConnected ? Colors.green : colors.onSurface.withOpacity(0.2),
                      size: _hcConnected ? 28 : 16,
                    ),
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
  const _SettingsContainer({required this.children});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
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

  const _SettingsTile({required this.icon, this.iconColor, required this.title, this.subtitle, this.trailing, this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10), 
        decoration: BoxDecoration(
          color: (iconColor ?? Theme.of(context).colorScheme.onSurface).withOpacity(0.1), 
          borderRadius: BorderRadius.circular(12),
        ), 
        child: Icon(icon, color: iconColor, size: 20)
      ), 
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), 
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor, indent: 70);
  }
}
