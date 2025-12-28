// lib/widgets/profile_avatar_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Haptics
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/inventory_repository.dart';
import '../screens/account_page.dart';
import '../screens/login_page.dart';

class ProfileAvatarButton extends StatelessWidget {
  final InventoryRepository repo;

  const ProfileAvatarButton({super.key, required this.repo});

  // 🟢 辅助方法：根据名字生成固定颜色
  Color _getUserColor(String name) {
    if (name.isEmpty) return Colors.grey;
    final colors = [
      Colors.blue.shade400,
      Colors.red.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        final isLoggedIn = session != null;

        String initial = 'U';
        // 🟢 获取更准确的名字用于生成颜色
        // 如果 Repo 里存了当前用户名，优先用那个，否则用 Email 前缀
        String displayNameForColor = 'User'; 

        if (isLoggedIn) {
          final email = session.user.email;
          if (email != null && email.isNotEmpty) {
            initial = email[0].toUpperCase();
            displayNameForColor = email;
          }
          // 尝试从 Repo 获取更准确的名字 (如果有的话，需要将 Repo 改为 ChangeNotifier 监听才能实时更新，这里简单处理)
          // 实际项目中，这里可以监听 repo._currentUserName
        }

        // 1. 未登录：显示登录按钮
        if (!isLoggedIn) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Log In',
              icon: const Icon(Icons.login, color: Color(0xFF005F87)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
          );
        }

        // 2. 已登录：点击直接跳转 Account 页面
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact(); // 触感反馈
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccountPage(
                    repo: repo, 
                    isLoggedIn: true,
                    onLogin: () {}, 
                    onLogout: () async {
                      await Supabase.instance.client.auth.signOut();
                    },
                  ),
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 主头像
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF005F87),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                
                // 🟢 右下角的用户颜色标识 (Tag)
                // 这样用户能知道自己代表什么颜色
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getUserColor(displayNameForColor), // 动态颜色
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}