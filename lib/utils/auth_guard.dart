// lib/utils/auth_guard.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/login_page.dart';

/// 检查是否已登录：
/// - 已登录：返回 true
/// - 未登录：弹出对话框 -> 跳登录页 -> 登录成功返回 true，其他情况返回 false
Future<bool> requireLogin(BuildContext context) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user != null) {
    // 已经登录，直接放行
    return true;
  }

  // 未登录：先问一下要不要去登录
  final goLogin = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      // 定义我们统一的主色调
      const primaryColor = Color(0xFF005F87);

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // 更圆润的角
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white, // 防止 Material 3 的默认紫色
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        
        // 标题区域：图标 + 文字
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Unlock AI Chef',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        
        // 内容区域：说明文案 + 权益列表
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign in to enable AI features and keep your data safe.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const _BenefitRow(icon: Icons.cloud_sync_outlined, text: 'Sync across all devices'),
            const SizedBox(height: 8),
            const _BenefitRow(icon: Icons.psychology_outlined, text: 'Smart expiry predictions'),
            const SizedBox(height: 8),
            const _BenefitRow(icon: Icons.restaurant_menu_rounded, text: 'Personalized AI recipes'),
          ],
        ),
        
        // 按钮区域
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Maybe Later'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Log In',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  if (goLogin != true) {
    return false;
  }

  // 跳到登录页
  if (!context.mounted) return false;
  final loggedIn = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const LoginPage(),
    ),
  );

  return loggedIn == true;
}

// 辅助组件：权益行
class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005F87);
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor.withOpacity(0.8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}