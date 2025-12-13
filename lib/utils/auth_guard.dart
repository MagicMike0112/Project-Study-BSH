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
      final theme = Theme.of(ctx);
      final primary = theme.colorScheme.primary;

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                color: primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Log in to unlock AI',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'AI recipes and smart expiry predictions are only available for logged-in users.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Save your fridge data securely',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Access AI features on any device',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log in'),
          ),
        ],
      );
    },
  );

  if (goLogin != true) {
    return false;
  }

  // 跳到登录页（LoginPage 登录成功时应当 Navigator.pop(context, true);）
  final loggedIn = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const LoginPage(),
    ),
  );

  return loggedIn == true;
}
