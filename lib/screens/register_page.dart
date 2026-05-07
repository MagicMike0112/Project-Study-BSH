// lib/screens/register_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // NOTE: legacy comment cleaned.
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  String? _gender;
  String? _ageGroup;

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  final _supabase = Supabase.instance.client;

  final _genders = const [
    'Female',
    'Male',
    'Other / prefer not to say',
  ];

  final _ageGroups = const [
    '<18',
    '18-24',
    '25-34',
    '35-44',
    '45-54',
    '55+',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    // NOTE: legacy comment cleaned.
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_pwdCtrl.text != _pwd2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.registerPasswordsDoNotMatch ?? 'Passwords do not match.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final name = _nameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final pwd = _pwdCtrl.text;

      // NOTE: legacy comment cleaned.
      await _supabase.auth.signUp(
        email: email,
        password: pwd,
        // NOTE: legacy comment cleaned.
        emailRedirectTo: 'https://bshpwa.vercel.app', 
        data: {
          'display_name': name,
          'gender': _gender,
          'age_group': _ageGroup,
          'country': _countryCtrl.text.trim(),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.registerSuccessCheckEmail ?? 'Sign-up successful! Please check your email to confirm.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // NOTE: legacy comment cleaned.
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.authUnexpectedError ?? 'Unexpected error, please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // NOTE: legacy comment cleaned.
      resizeToAvoidBottomInset: true,
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
                left: -80,
                top: -60,
                child: _GlowOrb(
                  size: 200,
                  color: scheme.secondary.withValues(alpha: 0.15),
                ),
              ),
              Positioned(
                right: -60,
                bottom: -40,
                child: _GlowOrb(
                  size: 260,
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
              ),

              // NOTE: legacy comment cleaned.
              Positioned(
                top: 0,
                left: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: IconButton(
                    tooltip: l10n?.registerBackToLogin ?? 'Back to Login',
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),

              // NOTE: legacy comment cleaned.
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
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                        child: Form(
                          key: _formKey,
                          child: AutofillGroup( // NOTE: legacy comment cleaned.
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Header
                                Text(
                                  l10n?.registerCreateAccountTitle ?? 'Create Account',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n?.registerCreateAccountSubtitle ?? 'Join us to manage your food smarter.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: scheme.onSurface.withValues(alpha: 0.6),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // NOTE: legacy comment cleaned.
                                _TechField(
                                  label: l10n?.registerNameLabel ?? 'Name',
                                  hint: l10n?.registerNameHint ?? 'How should we call you?',
                                  icon: Icons.person_outline_rounded,
                                  controller: _nameCtrl,
                                  keyboardType: TextInputType.name,
                                  autofillHints: const [AutofillHints.name], // NOTE: legacy comment cleaned.
                                  textInputAction: TextInputAction.next,     // NOTE: legacy comment cleaned.
                                  enabled: !_loading,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return l10n?.registerEnterName ?? 'Please enter your name';
                                    if (v.trim().length < 2) return l10n?.registerNameTooShort ?? 'Name is too short';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // NOTE: legacy comment cleaned.
                                _TechField(
                                  label: l10n?.registerEmailLabel ?? 'Email',
                                  hint: 'name@example.com',
                                  icon: Icons.mail_outline_rounded,
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  enabled: !_loading,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return l10n?.authPleaseEnterEmail ?? 'Please enter your email';
                                    if (!v.contains('@')) return l10n?.authEmailInvalid ?? 'Email looks invalid';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // NOTE: legacy comment cleaned.
                                _TechField(
                                  label: l10n?.registerPasswordLabel ?? 'Password',
                                  hint: l10n?.registerPasswordHint ?? 'Min 6 chars',
                                  icon: Icons.lock_outline_rounded,
                                  controller: _pwdCtrl,
                                  enabled: !_loading,
                                  obscureText: _obscure1,
                                  autofillHints: const [AutofillHints.newPassword],
                                  textInputAction: TextInputAction.next,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscure1 ? Icons.visibility_off : Icons.visibility,
                                      color: scheme.onSurface.withValues(alpha: 0.6),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                                  ),
                                  validator: (v) => (v == null || v.length < 6)
                                      ? (l10n?.authAtLeast6Chars ?? 'At least 6 characters')
                                      : null,
                                ),
                                const SizedBox(height: 12),

                                // NOTE: legacy comment cleaned.
                                _TechField(
                                  label: l10n?.registerRepeatPasswordLabel ?? 'Repeat Password',
                                  hint: l10n?.registerRepeatPasswordHint ?? 'Confirm password',
                                  icon: Icons.lock_reset_rounded,
                                  controller: _pwd2Ctrl,
                                  enabled: !_loading,
                                  obscureText: _obscure2,
                                  autofillHints: const [AutofillHints.newPassword],
                                  textInputAction: TextInputAction.done, // NOTE: legacy comment cleaned.
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscure2 ? Icons.visibility_off : Icons.visibility,
                                      color: scheme.onSurface.withValues(alpha: 0.6),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                                  ),
                                  validator: (v) =>
                                      (v != _pwdCtrl.text) ? (l10n?.registerPasswordsDoNotMatchInline ?? 'Passwords do not match') : null,
                                ),
                                const SizedBox(height: 20),

                                // Divider
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        l10n?.registerProfileDetailsTitle ?? 'PROFILE DETAILS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSurface.withValues(alpha: 0.5),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1))),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Gender Dropdown
                                _TechDropdown(
                                  label: l10n?.registerGenderLabel ?? 'Gender',
                                  icon: Icons.wc_rounded,
                                  value: _gender,
                                  items: _genders,
                                  enabled: !_loading,
                                  onChanged: (v) => setState(() => _gender = v),
                                  validator: (v) => v == null ? (l10n?.registerRequired ?? 'Required') : null,
                                ),
                                const SizedBox(height: 12),

                                // Age Group Dropdown
                                _TechDropdown(
                                  label: l10n?.registerAgeGroupLabel ?? 'Age Group',
                                  icon: Icons.cake_rounded,
                                  value: _ageGroup,
                                  items: _ageGroups,
                                  enabled: !_loading,
                                  onChanged: (v) => setState(() => _ageGroup = v),
                                  validator: (v) => v == null ? (l10n?.registerRequired ?? 'Required') : null,
                                ),
                                const SizedBox(height: 12),

                                // NOTE: legacy comment cleaned.
                                _TechField(
                                  label: l10n?.registerCountryLabel ?? 'Country',
                                  hint: l10n?.registerCountryHint ?? 'e.g. Germany',
                                  icon: Icons.public_rounded,
                                  controller: _countryCtrl,
                                  textInputAction: TextInputAction.done,
                                  enabled: !_loading,
                                  // NOTE: legacy comment cleaned.
                                  onFieldSubmitted: (_) => _register(), // NOTE: legacy comment cleaned.
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? (l10n?.registerPleaseEnterCountry ?? 'Please tell us your country')
                                      : null,
                                ),
                                const SizedBox(height: 32),

                                // Sign Up Button
                                SizedBox(
                                  height: 50,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [
                                          scheme.primary,
                                          scheme.primary.withValues(alpha: 0.8),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: scheme.primary.withValues(alpha: 0.25),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
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
                                      onPressed: _loading ? null : _register,
                                      child: _loading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              l10n?.registerCreateAccountTitle ?? 'Create Account',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

// --------------------------------------------------------
// NOTE: legacy comment cleaned.
// --------------------------------------------------------

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
  // NOTE: legacy comment cleaned.
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

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
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      obscureText: obscureText,
      validator: validator,
      // NOTE: legacy comment cleaned.
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.primary.withValues(alpha: 0.08),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1F24) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.8), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _TechDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _TechDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      initialValue: value,
      borderRadius: BorderRadius.circular(24),
      elevation: 12,
      menuMaxHeight: 360,
      dropdownColor: isDark ? const Color(0xFF1A1E25) : Colors.white,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 15))))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
      icon: Icon(Icons.arrow_drop_down_rounded, color: scheme.onSurface.withValues(alpha: 0.6)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.primary.withValues(alpha: 0.08),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1F24) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}



