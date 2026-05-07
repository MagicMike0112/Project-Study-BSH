// lib/screens/login_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  // NOTE: legacy comment cleaned.
  final bool allowSkip;

  const LoginPage({super.key, this.allowSkip = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final pwd = _pwdCtrl.text;

      await _supabase.auth.signInWithPassword(
        email: email,
        password: pwd,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // NOTE: legacy comment cleaned.
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.authUnexpectedError ?? 'Unexpected error, please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.authEnterEmailFirst ?? 'Please enter your email first.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        // NOTE: legacy comment cleaned.
        redirectTo: 'https://smart-home-reset-password.vercel.app/',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.authResetEmailSent ??
                'Password reset email sent. Please check your inbox.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.authResetEmailFailed ?? 'Failed to send reset email.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToRegister() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterPage(),
      ),
    );

    if (result == true && mounted) {
      // NOTE: legacy comment cleaned.
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // NOTE: legacy comment cleaned.
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF0F141A) : const Color(0xFFF6F8FA),
              scheme.primary.withValues(alpha: isDark ? 0.18 : 0.06),
              scheme.secondary.withValues(alpha: isDark ? 0.12 : 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // NOTE: legacy comment cleaned.
              Positioned(
                right: -80,
                top: -90,
                child: _GlowOrb(
                  size: 220,
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                left: -70,
                bottom: -90,
                child: _GlowOrb(
                  size: 240,
                  color: scheme.secondary.withValues(alpha: 0.16),
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: theme.cardColor.withValues(alpha: isDark ? 0.94 : 0.92),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // NOTE: legacy comment cleaned.
                              Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          scheme.primary.withValues(alpha: 0.18),
                                          scheme.primary.withValues(alpha: 0.08),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: scheme.primary.withValues(alpha: 0.20),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.lock_outline,
                                      color: scheme.primary,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n?.loginWelcomeBack ?? 'Welcome back',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.2,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n?.loginWelcomeSubtitle ?? 'Log in to sync your inventory across devices.',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: scheme.onSurface.withValues(alpha: 0.6),
                                                height: 1.25,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // Email
                              _TechField(
                                label: 'Email',
                                hint: 'name@example.com',
                                icon: Icons.mail_outline,
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                enabled: !_loading,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return l10n?.authPleaseEnterEmail ?? 'Please enter your email';
                                  }
                                  if (!v.contains('@')) {
                                    return l10n?.authEmailInvalid ?? 'Email looks invalid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Password
                              _TechField(
                                label: 'Password',
                                hint: '********',
                                icon: Icons.lock_outline,
                                controller: _pwdCtrl,
                                enabled: !_loading,
                                obscureText: _obscure,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return l10n?.authPleaseEnterPassword ?? 'Please enter your password';
                                  }
                                  if (v.length < 6) {
                                    return l10n?.authAtLeast6Chars ?? 'At least 6 characters';
                                  }
                                  return null;
                                },
                                suffix: IconButton(
                                  tooltip: _obscure ? (l10n?.authShowPassword ?? 'Show password') : (l10n?.authHidePassword ?? 'Hide password'),
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off : Icons.visibility,
                                    color: scheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  onPressed: _loading
                                      ? null
                                      : () => setState(() => _obscure = !_obscure),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading ? null : _resetPassword,
                                  child: Text(l10n?.authForgotPassword ?? 'Forgot password?'),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // NOTE: legacy comment cleaned.
                              SizedBox(
                                height: 50,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        scheme.primary,
                                        scheme.primary.withValues(alpha: 0.78),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: scheme.primary.withValues(alpha: 0.22),
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
                                    onPressed: _loading ? null : _login,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : Text(l10n?.authLogIn ?? 'Log in',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // NOTE: legacy comment cleaned.
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n?.authOr ?? 'OR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurface.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n?.authNoAccount ?? "Don't have an account?",
                                    style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.8)),
                                  ),
                                  TextButton(
                                    onPressed: _loading ? null : _goToRegister,
                                    child: Text(l10n?.authSignUp ?? 'Sign up'),
                                  ),
                                ],
                              ),

                              if (widget.allowSkip) ...[
                                const SizedBox(height: 2),
                                Center(
                                  child: TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () {
                                            Navigator.pop(context, false);
                                          },
                                    child: Text(
                                      l10n?.authSkipForNow ?? 'Skip for now',
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // NOTE: legacy comment cleaned.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: l10n?.authBack ?? 'Back',
                          onPressed: _loading ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Spacer(),
                      ],
                    ),
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

// NOTE: legacy comment cleaned.
class _TechField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _TechField({
    required this.label,
    required this.icon,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.enabled = true,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: scheme.primary.withValues(alpha: 0.08),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1F24) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.55), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.75), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// NOTE: legacy comment cleaned.
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
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}




