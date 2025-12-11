import 'package:flutter/material.dart';
import '../repositories/inventory_repository.dart';
import 'today_page.dart';
import 'inventory_page.dart';
import 'impact_page.dart';
import 'add_food_page.dart';
import 'account_page.dart';

class MainScaffold extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback onLoginRequested;
  final VoidCallback onLogoutRequested;

  const MainScaffold({
    super.key,
    required this.isLoggedIn,
    required this.onLoginRequested,
    required this.onLogoutRequested,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  bool _showFabMenu = false;

  late Future<InventoryRepository> _repoFuture;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _repoFuture = InventoryRepository.create();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _refresh(InventoryRepository repo) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InventoryRepository>(
      future: _repoFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Init error:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final repo = snapshot.data!;

        final pages = [
          TodayPage(repo: repo, onRefresh: () => _refresh(repo)),
          InventoryPage(repo: repo, onRefresh: () => _refresh(repo)),
          ImpactPage(repo: repo),
          AccountPage(
            isLoggedIn: widget.isLoggedIn,
            onLogin: widget.onLoginRequested,
            onLogout: widget.onLogoutRequested,
          ),
        ];

        // 只在 Today / Inventory 显示 FAB
        final bool fabEnabled = _currentIndex <= 1;

        return Scaffold(
          body: PageView(
            controller: _pageController,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
                _showFabMenu = false;
              });
            },
            children: pages,
          ),

          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) {
              setState(() {
                _currentIndex = idx;
                _showFabMenu = false;
              });
              _pageController.animateToPage(
                idx,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            },
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
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),

          floatingActionButton: _buildExpandableFab(repo, fabEnabled),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  Widget _buildExpandableFab(InventoryRepository repo, bool enabled) {
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: SizedBox(
          width: 120,
          height: 260,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              _FabActionButton(
                index: 0,
                icon: Icons.edit,
                label: 'Manual',
                visible: _showFabMenu,
                onTap: () => _navigateToAdd(repo, 0),
              ),
              _FabActionButton(
                index: 1,
                icon: Icons.camera_alt,
                label: 'Photo',
                visible: _showFabMenu,
                onTap: () => _navigateToAdd(repo, 1),
              ),
              _FabActionButton(
                index: 2,
                icon: Icons.mic,
                label: 'Voice',
                visible: _showFabMenu,
                onTap: () => _navigateToAdd(repo, 2),
              ),
              FloatingActionButton(
                onPressed: !enabled
                    ? null
                    : () => setState(() => _showFabMenu = !_showFabMenu),
                backgroundColor: const Color(0xFF005F87),
                child: Icon(
                  _showFabMenu ? Icons.close : Icons.add,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAdd(InventoryRepository repo, int tabIndex) async {
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
    _refresh(repo);
  }
}

class _FabActionButton extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool visible;
  final VoidCallback onTap;

  const _FabActionButton({
    required this.index,
    required this.icon,
    required this.label,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double baseOffset = 56.0;
    final duration = Duration(milliseconds: 220 + index * 40);
    final curve = Curves.easeOutBack;

    return AnimatedPositioned(
      duration: duration,
      curve: curve,
      right: 0,
      bottom: visible ? (baseOffset * (index + 1)) : 0,
      child: AnimatedOpacity(
        duration: duration,
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: duration,
          curve: curve,
          offset: visible ? Offset.zero : const Offset(0, 0.3),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FloatingActionButton.small(
                  heroTag: '${label}_fab',
                  onPressed: onTap,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF005F87),
                  child: Icon(icon, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
