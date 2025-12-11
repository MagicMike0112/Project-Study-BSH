// lib/screens/auth_root.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main_scaffold.dart';
import 'login_page.dart';

class AuthRoot extends StatefulWidget {
  const AuthRoot({super.key});

  @override
  State<AuthRoot> createState() => _AuthRootState();
}

class _AuthRootState extends State<AuthRoot> {
  bool _isLoggedIn = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  /// 启动时检查：是否已登录 / 是否第一次打开
  Future<void> _initAuth() async {
    final client = Supabase.instance.client;

    // 1. 读取当前 session，判断是否已经登录
    final session = client.auth.currentSession;
    _isLoggedIn = session != null;

    // 2. 看看是否已经弹过“首次登录提示”
    final prefs = await SharedPreferences.getInstance();
    final hasSeenPrompt =
        prefs.getBool('hasSeenLoginPrompt_v1') ?? false;

    setState(() {
      _initialized = true;
    });

    // 3. 逻辑：第一次打开 + 未登录 → 自动弹登录页，允许 Skip
    if (!hasSeenPrompt && !_isLoggedIn) {
      await prefs.setBool('hasSeenLoginPrompt_v1', true);

      // 等首帧 build 完成再 push，避免 context 报错
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openLoginScreen(allowSkip: true);
      });
    }
  }

  /// 打开登录 / 注册页面
  /// - allowSkip = true → 显示 Skip 按钮
  /// - 登录/注册成功时，LoginPage 用 `Navigator.pop(context, true)` 返回
  Future<void> _openLoginScreen({bool allowSkip = false}) async {
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LoginPage(allowSkip: allowSkip),
      ),
    );

    // 登录成功 → 更新本地状态
    if (loggedIn == true && mounted) {
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  /// 统一登出逻辑，给 Account 页调用
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Supabase / SharedPreferences 还没初始化完 → loading 页
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 主框架：把“是否登录 / 登录 / 登出回调”传给 MainScaffold
    return MainScaffold(
      isLoggedIn: _isLoggedIn,
      // 从底部 Account tab 触发登录：这里不允许 Skip，只能登录/注册
      onLoginRequested: () => _openLoginScreen(allowSkip: false),
      onLogoutRequested: _logout,
    );
  }
}
