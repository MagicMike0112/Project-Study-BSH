// lib/widgets/profile_avatar_button.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/account_page.dart';
import '../screens/login_page.dart';

class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
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
        tooltip: 'Account & Settings',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AccountPage(
                isLoggedIn: isLoggedIn,
                // 定义登录回调
                onLogin: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                // 定义登出回调
                onLogout: () async {
                  await Supabase.instance.client.auth.signOut();
                  Navigator.pop(context); // 退出 Account 页面
                },
              ),
            ),
          );
        },
        icon: Container(
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
    );
  }
}