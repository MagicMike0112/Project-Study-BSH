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

    // 👇 这里加上 emailRedirectTo，和你 Supabase 里的 redirect 配置完全一致
    final authRes = await _supabase.auth.signUp(
      email: email,
      password: pwd,
      emailRedirectTo: 'https://bshpwa.vercel.app', // ★ 关键修改
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign up'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_alt_1_outlined, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Create your account',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A few details help us understand who is using Smart Food Home.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 24),

                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                            border: OutlineInputBorder(),
                          ),
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
                        TextFormField(
                          controller: _pwdCtrl,
                          obscureText: _obscure1,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure1
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() => _obscure1 = !_obscure1);
                              },
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please set a password';
                            }
                            if (v.length < 6) {
                              return 'At least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Repeat password
                        TextFormField(
                          controller: _pwd2Ctrl,
                          obscureText: _obscure2,
                          decoration: InputDecoration(
                            labelText: 'Repeat password',
                            prefixIcon: const Icon(Icons.lock_reset_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure2
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() => _obscure2 = !_obscure2);
                              },
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please repeat your password';
                            }
                            if (v != _pwdCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Gender
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(),
                          ),
                          value: _gender,
                          items: _genders
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _gender = v),
                          validator: (v) =>
                              v == null ? 'Please choose your gender' : null,
                        ),
                        const SizedBox(height: 12),

                        // Age group
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Age group',
                            border: OutlineInputBorder(),
                          ),
                          value: _ageGroup,
                          items: _ageGroups
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _ageGroup = v),
                          validator: (v) => v == null
                              ? 'Please choose an age group'
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Country
                        TextFormField(
                          controller: _countryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            prefixIcon: Icon(Icons.public_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please tell us your country';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _register,
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Create account'),
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
    );
  }
}
