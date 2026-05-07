import 'package:flutter/material.dart';
// lib/widgets/profile_avatar_button.dart
import '../utils/app_haptics.dart';
import 'package:flutter/services.dart'; // Haptics
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/inventory_repository.dart';
import '../screens/account_page.dart';
import '../utils/reveal_route.dart';

class ProfileAvatarButton extends StatelessWidget {
  final InventoryRepository repo;

  const ProfileAvatarButton({super.key, required this.repo});

  void _openAccountPage(BuildContext context, {required bool isLoggedIn}) {
    Navigator.of(context).push(
      topRightRevealRoute(
        AccountPage(
          repo: repo,
          isLoggedIn: isLoggedIn,
          onLogin: () {},
          onLogout: () async {
            await Supabase.instance.client.auth.signOut();
          },
        ),
      ),
    );
  }

  // NOTE: legacy comment cleaned.
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
        // NOTE: legacy comment cleaned.
        // NOTE: legacy comment cleaned.
        String displayNameForColor = 'User'; 

        if (isLoggedIn) {
          final email = session.user.email;
          if (email != null && email.isNotEmpty) {
            initial = email[0].toUpperCase();
            displayNameForColor = email;
          }
          // NOTE: legacy comment cleaned.
          // NOTE: legacy comment cleaned.
        }

        // NOTE: legacy comment cleaned.
        if (!isLoggedIn) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                AppHaptics.selection();
                _openAccountPage(context, isLoggedIn: false);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.settings, size: 18, color: Colors.white),
                ),
              ),
            ),
          );
        }

        // NOTE: legacy comment cleaned.
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              AppHaptics.selection(); // NOTE: legacy comment cleaned.
              _openAccountPage(context, isLoggedIn: true);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // NOTE: legacy comment cleaned.
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF005F87),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
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
                
                // NOTE: legacy comment cleaned.
                // NOTE: legacy comment cleaned.
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getUserColor(displayNameForColor), // NOTE: legacy comment cleaned.
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







