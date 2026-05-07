// lib/screens/auth_root.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/inventory_repository.dart';
import 'main_scaffold.dart';
import 'login_page.dart';
import 'guest_shopping_list_page.dart';

class AuthRoot extends StatefulWidget {
  const AuthRoot({super.key});

  @override
  State<AuthRoot> createState() => _AuthRootState();
}

class _AuthRootState extends State<AuthRoot> {
  bool _initialized = false;
  bool _handledGuestLink = false;
  bool _didSyncAfterLogin = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
    _maybeOpenGuestList();
  }

  // NOTE: legacy comment cleaned.
  // NOTE: legacy comment cleaned.
  Future<void> _checkFirstLaunch() async {
    setState(() {
      _initialized = true;
    });
  }

  void _maybeOpenGuestList() {
    if (_handledGuestLink) return;
    _handledGuestLink = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = GuestShoppingListPage.resolveToken(
        RouteSettings(name: Uri.base.toString()),
      );
      if (token == null || token.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GuestShoppingListPage(shareToken: token),
        ),
      );
    });
  }

  // NOTE: legacy comment cleaned.
  Future<void> _openLoginScreen({bool allowSkip = false}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LoginPage(allowSkip: allowSkip),
      ),
    );
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final repo = Provider.of<InventoryRepository>(context, listen: false);
      await repo.refreshAll(force: true);
      _didSyncAfterLogin = true;
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    // NOTE: legacy comment cleaned.
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: legacy comment cleaned.
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // NOTE: legacy comment cleaned.
    // NOTE: legacy comment cleaned.
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        
        // NOTE: legacy comment cleaned.
        final session = snapshot.data?.session;
        final isLoggedIn = session != null;
        // NOTE: legacy comment cleaned.
    
        if (!isLoggedIn) {
          _didSyncAfterLogin = false;
        } else if (!_didSyncAfterLogin) {
          final repo = Provider.of<InventoryRepository>(context, listen: false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            repo.refreshAll(force: true);
          });
          _didSyncAfterLogin = true;
        }

        return MainScaffold(
          isLoggedIn: isLoggedIn,
          // NOTE: legacy comment cleaned.
          onLoginRequested: () => _openLoginScreen(allowSkip: false),
          onLogoutRequested: _logout,
        );
      },
    );
  }
}

