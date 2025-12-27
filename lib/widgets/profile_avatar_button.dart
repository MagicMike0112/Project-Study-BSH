import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/account_page.dart';
import '../screens/login_page.dart';

class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔴 核心修复：使用 StreamBuilder 监听 Auth 变化
    // 这样无论何时登出，这个按钮都会立刻重绘
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 获取最新的 session 状态
        final session = Supabase.instance.client.auth.currentSession;
        final isLoggedIn = session != null;

        // 获取用户首字母 (如果有)
        String initial = 'U';
        if (isLoggedIn) {
          final email = session.user.email;
          if (email != null && email.isNotEmpty) {
            initial = email[0].toUpperCase();
          }
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            tooltip: isLoggedIn ? 'Account & Settings' : 'Log In',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccountPage(
                    isLoggedIn: isLoggedIn,
                    // 登录回调
                    onLogin: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                      // 登录页面返回后，StreamBuilder 会自动检测到变化并更新 UI
                    },
                    // 登出回调
                    onLogout: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        Navigator.pop(context); // 退出 Account 页面返回 Impact
                      }
                    },
                  ),
                ),
              );
            },
            icon: AnimatedSwitcher(
              // 加一个小动画，让切换更丝滑
              duration: const Duration(milliseconds: 300),
              child: Container(
                // 必须加 key，AnimatedSwitcher 才能识别组件变化
                key: ValueKey<bool>(isLoggedIn),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isLoggedIn ? const Color(0xFF005F87) : Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: isLoggedIn
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.grey, size: 20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}