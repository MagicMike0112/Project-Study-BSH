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
  // 注意：在实际大型应用中，repo 应该通过 Provider 或 GetIt 注入
  final InventoryRepository _repo = InventoryRepository(); 
  bool _showFabMenu = false;

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(repo: _repo, onRefresh: _refresh),
      InventoryPage(repo: _repo, onRefresh: _refresh),
      ImpactPage(repo: _repo),
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
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.eco_outlined), selectedIcon: Icon(Icons.eco), label: 'Impact'),
        ],
      ),
      floatingActionButton: _currentIndex != 2 ? _buildExpandableFab() : null,
    );
  }

  // FAB 逻辑保持不变... (省略部分代码以节省篇幅，直接复制原代码中的 _buildExpandableFab 和 _FabOption)
  Widget _buildExpandableFab() {
     // ... 原代码 ...
     return Column(
       mainAxisSize: MainAxisSize.min,
       crossAxisAlignment: CrossAxisAlignment.end,
       children: [
         if (_showFabMenu) ...[
           FabOption(icon: Icons.mic, label: 'Voice', onTap: () => _navigateToAdd(2)),
           FabOption(icon: Icons.camera_alt, label: 'Photo', onTap: () => _navigateToAdd(1)),
           FabOption(icon: Icons.edit, label: 'Manual', onTap: () => _navigateToAdd(0)),
         ],
         FloatingActionButton(
           onPressed: () => setState(() => _showFabMenu = !_showFabMenu),
           backgroundColor: const Color(0xFF005F87),
           child: Icon(_showFabMenu ? Icons.close : Icons.add, color: Colors.white),
         ),
       ],
     );
  }
  
  void _navigateToAdd(int tabIndex) async {
    setState(() => _showFabMenu = false);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddFoodPage(repo: _repo, initialTab: tabIndex)),
    );
    _refresh();
  }
}

class FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const FabOption({super.key, required this.icon, required this.label, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
     // ... 直接复制原代码中的 _FabOption ...
     return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
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