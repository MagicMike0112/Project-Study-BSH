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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  /// 仅用于检查“是否第一次打开 App”以决定是否弹窗
  /// 登录状态的检查现在移交给 StreamBuilder 自动处理
  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenPrompt = prefs.getBool('hasSeenLoginPrompt_v1') ?? false;
    
    // 获取当前是否有 Session (同步检查)
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;

    setState(() {
      _initialized = true;
    });

    // 逻辑：第一次打开 + 未登录 → 自动弹登录页
    if (!hasSeenPrompt && !isLoggedIn) {
      await prefs.setBool('hasSeenLoginPrompt_v1', true);
      
      if (mounted) {
        // 等首帧 build 完成再 push
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openLoginScreen(allowSkip: true);
        });
      }
    }
  }

  /// 打开登录页面
  Future<void> _openLoginScreen({bool allowSkip = false}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LoginPage(allowSkip: allowSkip),
      ),
    );
    // 注意：这里不需要手动 setState(_isLoggedIn = true)
    // 因为 Login 成功后，Supabase 会发出 AuthStateChange 事件
    // 下面的 StreamBuilder 会自动捕获并刷新 UI
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    // 同样不需要手动 setState，StreamBuilder 会自动处理
  }

  @override
  Widget build(BuildContext context) {
    // 1. 初始化 loading (读取 SharedPreferences)
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. 核心修改：使用 StreamBuilder 监听 Auth 变化
    // 这样登录/注销后，App 不需要重启就能立即刷新状态
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        
        // 获取最新的 Session
        final session = snapshot.data?.session;
        // 如果 session 存在，即为已登录
        final isLoggedIn = session != null;

        return MainScaffold(
          isLoggedIn: isLoggedIn,
          // 点击 Account tab 的登录按钮
          onLoginRequested: () => _openLoginScreen(allowSkip: false),
          onLogoutRequested: _logout,
        );
      },
    );
  }
}