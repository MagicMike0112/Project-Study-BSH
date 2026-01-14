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

  // 控制器
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
    '18–24',
    '25–34',
    '35–44',
    '45–54',
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
    // 隐藏键盘，避免遮挡 SnackBar 或 Loading
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_pwdCtrl.text != _pwd2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
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

      // Supabase 注册
      await _supabase.auth.signUp(
        email: email,
        password: pwd,
        // 如果是 Web PWA，这个链接没问题；如果是 App，建议配置 Deep Link
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
        const SnackBar(
          content: Text(
            'Sign-up successful! Please check your email to confirm.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // 返回 true 表示注册成功
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
        const SnackBar(
          content: Text('Unexpected error, please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // 🟢 确保键盘弹出时页面可以滚动
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF0F141A) : const Color(0xFFF6F8FA),
              scheme.primary.withOpacity(isDark ? 0.18 : 0.06),
              scheme.secondary.withOpacity(isDark ? 0.12 : 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // --- 背景光晕特效 ---
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

              // --- 顶部返回按钮 ---
              Positioned(
                top: 0,
                left: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: IconButton(
                    tooltip: 'Back to Login',
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),

              // --- 主内容区域 ---
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: theme.cardColor.withOpacity(isDark ? 0.94 : 0.92),
                        border: Border.all(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.35 : 0.1),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                        child: Form(
                          key: _formKey,
                          child: AutofillGroup( // 🟢 启用表单自动填充组
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Header
                                Text(
                                  'Create Account',
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
                                  'Join us to manage your food smarter.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: scheme.onSurface.withOpacity(0.6),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // 🟢 Name Input
                                _TechField(
                                  label: 'Name',
                                  hint: 'How should we call you?',
                                  icon: Icons.person_outline_rounded,
                                  controller: _nameCtrl,
                                  keyboardType: TextInputType.name,
                                  autofillHints: const [AutofillHints.name], // 🟢 自动填充
                                  textInputAction: TextInputAction.next,     // 🟢 下一项
                                  enabled: !_loading,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Please enter your name';
                                    if (v.trim().length < 2) return 'Name is too short';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // 🟢 Email Input
                                _TechField(
                                  label: 'Email',
                                  hint: 'name@example.com',
                                  icon: Icons.mail_outline_rounded,
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  enabled: !_loading,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                                    if (!v.contains('@')) return 'Email looks invalid';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // 🟢 Password Input
                                _TechField(
                                  label: 'Password',
                                  hint: 'Min 6 chars',
                                  icon: Icons.lock_outline_rounded,
                                  controller: _pwdCtrl,
                                  enabled: !_loading,
                                  obscureText: _obscure1,
                                  autofillHints: const [AutofillHints.newPassword],
                                  textInputAction: TextInputAction.next,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscure1 ? Icons.visibility_off : Icons.visibility,
                                      color: scheme.onSurface.withOpacity(0.6),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                                  ),
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'At least 6 characters'
                                      : null,
                                ),
                                const SizedBox(height: 12),

                                // 🟢 Repeat Password
                                _TechField(
                                  label: 'Repeat Password',
                                  hint: 'Confirm password',
                                  icon: Icons.lock_reset_rounded,
                                  controller: _pwd2Ctrl,
                                  enabled: !_loading,
                                  obscureText: _obscure2,
                                  autofillHints: const [AutofillHints.newPassword],
                                  textInputAction: TextInputAction.done, // 🟢 最后一项输入
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscure2 ? Icons.visibility_off : Icons.visibility,
                                      color: scheme.onSurface.withOpacity(0.6),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                                  ),
                                  validator: (v) =>
                                      (v != _pwdCtrl.text) ? 'Passwords do not match' : null,
                                ),
                                const SizedBox(height: 20),

                                // Divider
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        'PROFILE DETAILS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSurface.withOpacity(0.5),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1))),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Gender Dropdown
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

                                // Age Group Dropdown
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

                                // 🟢 Country Input
                                _TechField(
                                  label: 'Country',
                                  hint: 'e.g. Germany',
                                  icon: Icons.public_rounded,
                                  controller: _countryCtrl,
                                  textInputAction: TextInputAction.done,
                                  enabled: !_loading,
                                  // 这里也可以加上 AutofillHints.countryName，但 Flutter 某些版本支持有限
                                  onFieldSubmitted: (_) => _register(), // 🟢 填完直接提交
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// 复用组件 (已增强 Autofill 和 InputAction 支持)
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
  // 🟢 新增参数
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
      // 🟢 关键优化配置
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4), fontSize: 14),
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
        fillColor: isDark ? const Color(0xFF1C1F24) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08)),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 15))))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
      icon: Icon(Icons.arrow_drop_down_rounded, color: scheme.onSurface.withOpacity(0.6)),
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
        fillColor: isDark ? const Color(0xFF1C1F24) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08)),
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
