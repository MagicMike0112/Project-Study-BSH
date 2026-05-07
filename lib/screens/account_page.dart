// lib/screens/account_page.dart
import 'package:flutter/material.dart';
import '../utils/app_haptics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../repositories/inventory_repository.dart';
import 'family_page.dart';
import 'notification_settings_page.dart';
import 'login_page.dart';
import '../utils/bsh_toast.dart';
import '../utils/locale_controller.dart';
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
  static const Color _primaryColor = Color(0xFF004A77);

  bool _studentMode = false;

  @override
  void initState() {
    super.initState();
    _initStudentMode();
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
    AppHaptics.selection();
    
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

  void _handleLogin() {
    AppHaptics.success();
    widget.onLogin();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage(allowSkip: false)),
    );
  }

  String _themeLabel(ThemeMode mode) {
    final l10n = AppLocalizations.of(context);
    switch (mode) {
      case ThemeMode.system:
        return l10n?.themeFollowSystem ?? 'Follow system';
      case ThemeMode.light:
        return l10n?.themeLight ?? 'Light';
      case ThemeMode.dark:
        return l10n?.themeDark ?? 'Dark';
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
                AppLocalizations.of(ctx)?.themeTitle ?? 'Theme',
                style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(AppLocalizations.of(ctx)?.themeFollowSystem ?? 'Follow system'),
                trailing: themeController.themeMode == ThemeMode.system
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  themeController.setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(AppLocalizations.of(ctx)?.themeLight ?? 'Light'),
                trailing: themeController.themeMode == ThemeMode.light
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  themeController.setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(AppLocalizations.of(ctx)?.themeDark ?? 'Dark'),
                trailing: themeController.themeMode == ThemeMode.dark
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  themeController.setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  String _languageLabel(AppLocalizations l10n, Locale? locale) {
    final code = locale?.languageCode;
    if (code == 'en') return l10n.languageEnglish;
    if (code == 'zh') return l10n.languageChinese;
    if (code == 'de') return l10n.languageGerman;
    return l10n.languageSystem;
  }

  void _showLanguagePicker(LocaleController localeController, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) {
        final currentCode = localeController.locale?.languageCode;
        void select(String? code) {
          final locale = code == null ? null : Locale(code);
          localeController.setLocale(locale);
          AppHaptics.selection();
          Navigator.pop(ctx);
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                l10n.prefLanguageTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(l10n.languageSystem),
                trailing: currentCode == null ? const Icon(Icons.check_rounded) : null,
                onTap: () => select(null),
              ),
              ListTile(
                title: Text(l10n.languageEnglish),
                trailing: currentCode == 'en' ? const Icon(Icons.check_rounded) : null,
                onTap: () => select('en'),
              ),
              ListTile(
                title: Text(l10n.languageChinese),
                trailing: currentCode == 'zh' ? const Icon(Icons.check_rounded) : null,
                onTap: () => select('zh'),
              ),
              ListTile(
                title: Text(l10n.languageGerman),
                trailing: currentCode == 'de' ? const Icon(Icons.check_rounded) : null,
                onTap: () => select('de'),
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
    final sectionTitleColor = colors.onSurface.withValues(alpha: 0.55);
    const sectionTitleSize = 12.0;

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        final bool loggedIn = session != null;
        final String email = session?.user.email ?? '';
        final String name = session?.user.userMetadata?['full_name'] ?? 'User';
        final themeController = context.watch<ThemeController>();
        final localeController = context.watch<LocaleController>();
        final l10n = AppLocalizations.of(context);
        if (l10n == null) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              l10n.accountTitle,
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
                _buildSectionTitle(l10n.accountSectionMyHome, sectionTitleColor, sectionTitleSize),
                const SizedBox(height: 12),
                _buildFamilyCard(context),
                const SizedBox(height: 32),
              ],
              
              _buildSectionTitle(l10n.accountSectionPreferences, sectionTitleColor, sectionTitleSize),
              const SizedBox(height: 12),
              _SettingsContainer(
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_rounded,
                    iconColor: Colors.orange,
                    title: l10n.accountNotificationsTitle,
                    subtitle: l10n.accountNotificationsSubtitle,
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
                    title: l10n.accountNightModeTitle,
                    subtitle: _themeLabel(themeController.themeMode),
                    trailing: Text(
                      _themeLabel(themeController.themeMode),
                      style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5), fontSize: 12),
                    ),
                    onTap: () => _showThemePicker(themeController),
                  ),

                  const _Divider(),

                  _SettingsTile(
                    icon: Icons.language_rounded,
                    iconColor: Colors.teal,
                    title: l10n.prefLanguageTitle,
                    subtitle: l10n.prefLanguageSubtitle,
                    trailing: Text(
                      _languageLabel(l10n, localeController.locale),
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => _showLanguagePicker(localeController, l10n),
                  ),

                  const _Divider(),

                  _SettingsTile(
                    icon: Icons.school_rounded,
                    iconColor: Colors.indigo,
                    title: l10n.accountStudentModeTitle,
                    subtitle: l10n.accountStudentModeSubtitle,
                    trailing: Switch.adaptive(
                      value: _studentMode,
                      activeThumbColor: _primaryColor,
                      onChanged: _toggleStudentMode,
                    ),
                    onTap: () => _toggleStudentMode(!_studentMode),
                  ),
                  
                  const _Divider(),
                  
                  _SettingsTile(
                    icon: Icons.card_giftcard_rounded,
                    iconColor: Colors.purple,
                    title: l10n.accountLoyaltyCardsTitle,
                    subtitle: l10n.accountLoyaltyCardsSubtitle,
                    onTap: null,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              _buildSectionTitle(l10n.accountSectionAbout, sectionTitleColor, sectionTitleSize),
              const SizedBox(height: 12),
              _SettingsContainer(
                children: [
                  _SettingsTile(
                    icon: Icons.privacy_tip_rounded,
                    iconColor: Colors.blueGrey,
                    title: l10n.accountPrivacyPolicyTitle,
                    onTap: null,
                  ),
                  const _Divider(),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.blueGrey,
                    title: l10n.accountVersionTitle,
                    trailing: Text(
                      '1.0.0 (Beta)',
                      style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5), fontSize: 13),
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
                      AppHaptics.success();
                      widget.onLogout();
                    },
                    icon: Icon(Icons.logout_rounded, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
                    label: Text(
                      l10n.accountSignOut, 
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.6),
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
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
              color: loggedIn ? const Color(0xFF1565C0) : colors.onSurface.withValues(alpha: 0.4),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(
                    loggedIn
                        ? (l10n?.accountHelloUser(name) ?? 'Hello, $name')
                        : (l10n?.accountGuestTitle ?? 'Guest Account'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loggedIn ? email : (l10n?.accountSignInHint ?? 'Sign in to sync your data'),
                    style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6)),
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
              child: Text(l10n?.accountLogIn ?? 'Log In', style: const TextStyle(fontSize: 14)),
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
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 16,
            )
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.home_rounded, color: _primaryColor, size: 30),
            const SizedBox(width: 16),
            Expanded(child: Text(widget.repo.currentFamilyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
          color: (iconColor ?? Theme.of(context).colorScheme.onSurface).withValues(alpha: 0.1), 
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







