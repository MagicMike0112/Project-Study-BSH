// lib/screens/account_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_settings_page.dart'; // 👈 新增：跳转到通知设置页

class AccountPage extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const AccountPage({
    super.key,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    final bool loggedIn = isLoggedIn && user != null;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 顶部卡片：登录状态
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: loggedIn
                  ? _buildLoggedInHeader(context, email)
                  : _buildLoggedOutHeader(context),
            ),
          ),
          const SizedBox(height: 24),

          // 合作伙伴
          Text(
            'Partners',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.kitchen_outlined),
                  title: Text('Home Connect (BSH appliances)'),
                  subtitle: Text('Planned integration – not available yet'),
                  trailing: Icon(Icons.chevron_right),
                  enabled: false, // 依然灰：还没实现
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.card_giftcard_outlined),
                  title: Text('PAYBACK / loyalty cards'),
                  subtitle: Text('Explore rewards for reducing food waste'),
                  trailing: Icon(Icons.chevron_right),
                  enabled: false, // 依然灰：还没实现
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 偏好设置
          Text(
            'Preferences',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 👇 这里从占位变成真正可点的入口
                ListTile(
                  leading: const Icon(Icons.notifications_none),
                  title: const Text('Notifications'),
                  subtitle: const Text('Reminders for items close to expiry'),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 隐私 & 法律
          Text(
            'Privacy & legal',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.insights_outlined),
                  title: Text('App data usage'),
                  subtitle: Text('How we use your feedback and behaviour'),
                  enabled: false,
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('Legal information'),
                  subtitle: Text('Terms of use, privacy policy'),
                  enabled: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (loggedIn)
            Center(
              child: SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  onPressed: onLogout,
                  label: const Text('Log out'),
                ),
              ),
            )
          else
            Center(
              child: SizedBox(
                width: 260,
                child: FilledButton(
                  onPressed: onLogin,
                  child: const Text('Log in / Sign up'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoggedOutHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start using Smart Food Home',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Log in to back up your inventory and prepare for future integrations with BSH appliances and loyalty programs.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[700]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onLogin,
            child: const Text('Log in / Sign up'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedInHeader(BuildContext context, String email) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 22,
          child: Icon(Icons.person_outline),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Logged in',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
