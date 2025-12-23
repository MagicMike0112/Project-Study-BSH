// lib/screens/register_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

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
    '18–24',
    '25–34',
    '35–44',
    '45–54',
    '55+',
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pwdCtrl.text != _pwd2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final pwd = _pwdCtrl.text;

      final authRes = await _supabase.auth.signUp(
        email: email,
        password: pwd,
        emailRedirectTo: 'https://bshpwa.vercel.app',
      );

      final user = authRes.user;
      if (user != null) {
        await _supabase.from('user_profiles').upsert({
          'id': user.id,
          'display_name': null,
          'locale': null,
          'has_homeconnect': false,
          'has_payback': false,
          'gender': _gender,
          'age_group': _ageGroup,
          'country': _countryCtrl.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign-up successful. Please confirm your email via the link we sent.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error, please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF6F8FA),
              scheme.primary.withOpacity(0.06),
              scheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 背景光晕 - 位置略微调整以区别于 Login 页面
              Positioned(
                left: -80,
                top: -60,
                child: _GlowOrb(
                  size: 200,
                  color: scheme.secondary.withOpacity(0.15),
                ),
              ),
              Positioned(
                right: -60,
                bottom: -40,
                child: _GlowOrb(
                  size: 260,
                  color: scheme.primary.withOpacity(0.12),
                ),
              ),

              // 顶部返回按钮
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: IconButton(
                      tooltip: 'Back to Login',
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
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
                        color: Colors.white.withOpacity(0.92),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.06),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header
                              const Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Join us to manage your food smarter.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Email
                              _TechField(
                                label: 'Email',
                                hint: 'name@example.com',
                                icon: Icons.mail_outline_rounded,
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                enabled: !_loading,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!v.contains('@')) {
                                    return 'Email looks invalid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Password
                              _TechField(
                                label: 'Password',
                                hint: 'Min 6 chars',
                                icon: Icons.lock_outline_rounded,
                                controller: _pwdCtrl,
                                enabled: !_loading,
                                obscureText: _obscure1,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure1 ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                                ),
                                validator: (v) => (v == null || v.length < 6)
                                    ? 'At least 6 characters'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Repeat Password
                              _TechField(
                                label: 'Repeat Password',
                                hint: 'Confirm password',
                                icon: Icons.lock_reset_rounded,
                                controller: _pwd2Ctrl,
                                enabled: !_loading,
                                obscureText: _obscure2,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure2 ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                                ),
                                validator: (v) =>
                                    (v != _pwdCtrl.text) ? 'Passwords do not match' : null,
                              ),
                              const SizedBox(height: 20),

                              // Profile Details Section
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey[300])),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      'PROFILE DETAILS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[500],
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey[300])),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Gender
                              _TechDropdown(
                                label: 'Gender',
                                icon: Icons.wc_rounded,
                                value: _gender,
                                items: _genders,
                                enabled: !_loading,
                                onChanged: (v) => setState(() => _gender = v),
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),

                              // Age Group
                              _TechDropdown(
                                label: 'Age Group',
                                icon: Icons.cake_rounded,
                                value: _ageGroup,
                                items: _ageGroups,
                                enabled: !_loading,
                                onChanged: (v) => setState(() => _ageGroup = v),
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),

                              // Country
                              _TechField(
                                label: 'Country',
                                hint: 'e.g. Germany',
                                icon: Icons.public_rounded,
                                controller: _countryCtrl,
                                enabled: !_loading,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Please tell us your country'
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
                                        scheme.primary.withOpacity(0.8),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: scheme.primary.withOpacity(0.25),
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
                                        : const Text(
                                            'Create Account',
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
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// 复用组件 (TechField, TechDropdown, GlowOrb)
// 建议将这些提取到 lib/widgets/auth_widgets.dart 中统一管理
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

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.primary.withOpacity(0.08),
            border: Border.all(color: scheme.primary.withOpacity(0.1)),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary.withOpacity(0.5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.8), width: 1.5),
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
    final scheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 15))))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
      icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[600]),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.primary.withOpacity(0.08),
            border: Border.all(color: scheme.primary.withOpacity(0.1)),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary.withOpacity(0.5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.5)),
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
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}