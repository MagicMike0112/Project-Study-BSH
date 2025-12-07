// lib/screens/main_scaffold.dart
import 'package:flutter/material.dart';

import '../repositories/inventory_repository.dart';
import 'today_page.dart';
import 'inventory_page.dart';
import 'impact_page.dart';
import 'add_food_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  // 仓库：改成“异步初始化 + 可为空”
  InventoryRepository? _repo;
  bool _isLoadingRepo = true;

  bool _showFabMenu = false;

  @override
  void initState() {
    super.initState();
    _initRepo();
  }

  Future<void> _initRepo() async {
    // 使用我们带本地持久化的工厂方法
    final repo = await InventoryRepository.create();

    if (!mounted) return;
    setState(() {
      _repo = repo;
      _isLoadingRepo = false;
    });
  }

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 仓库还没准备好 → 给个简单的 loading 页
    if (_isLoadingRepo || _repo == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final repo = _repo!;

    final pages = [
      TodayPage(repo: repo, onRefresh: _refresh),
      InventoryPage(repo: repo, onRefresh: _refresh),
      ImpactPage(repo: repo),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() {
          _currentIndex = idx;
          _showFabMenu = false;
        }),
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco),
            label: 'Impact',
          ),
        ],
      ),
      floatingActionButton:
          _currentIndex != 2 ? _buildExpandableFab(repo) : null,
    );
  }

  // 传 repo 进来，避免再次从 null 取
  Widget _buildExpandableFab(InventoryRepository repo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_showFabMenu) ...[
          FabOption(
            icon: Icons.mic,
            label: 'Voice',
            onTap: () => _navigateToAdd(repo, 2),
          ),
          FabOption(
            icon: Icons.camera_alt,
            label: 'Photo',
            onTap: () => _navigateToAdd(repo, 1),
          ),
          FabOption(
            icon: Icons.edit,
            label: 'Manual',
            onTap: () => _navigateToAdd(repo, 0),
          ),
        ],
        FloatingActionButton(
          onPressed: () => setState(() => _showFabMenu = !_showFabMenu),
          backgroundColor: const Color(0xFF005F87),
          child: Icon(
            _showFabMenu ? Icons.close : Icons.add,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _navigateToAdd(InventoryRepository repo, int tabIndex) async {
    setState(() => _showFabMenu = false);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodPage(
          repo: repo,
          initialTab: tabIndex,
        ),
      ),
    );

    _refresh();
  }
}

class FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const FabOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: label,
            onPressed: onTap,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF005F87),
            child: Icon(icon),
          ),
        ],
      ),
    );
  }
}
