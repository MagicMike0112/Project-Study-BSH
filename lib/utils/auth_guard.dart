// lib/utils/auth_guard.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/login_page.dart';

// NOTE: legacy comment cleaned.
// NOTE: legacy comment cleaned.
// NOTE: legacy comment cleaned.
Future<bool> requireLogin(BuildContext context) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user != null) {
    // NOTE: legacy comment cleaned.
    return true;
  }

  // NOTE: legacy comment cleaned.
  final goLogin = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      // NOTE: legacy comment cleaned.
      const primaryColor = Color(0xFF005F87);

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // NOTE: legacy comment cleaned.
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white, // NOTE: legacy comment cleaned.
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        
        // NOTE: legacy comment cleaned.
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
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
        
        // NOTE: legacy comment cleaned.
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
        
        // NOTE: legacy comment cleaned.
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

  // NOTE: legacy comment cleaned.
  if (!context.mounted) return false;
  final loggedIn = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const LoginPage(),
    ),
  );

  return loggedIn == true;
}

// NOTE: legacy comment cleaned.
class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005F87);
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor.withValues(alpha: 0.8)),
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


