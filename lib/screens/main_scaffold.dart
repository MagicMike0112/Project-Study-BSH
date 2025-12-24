// lib/screens/main_scaffold.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../repositories/inventory_repository.dart';
import 'today_page.dart';
import 'inventory_page.dart';
import 'impact_page.dart';
import 'add_food_page.dart';
import 'shopping_list_page.dart'; 

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

  static const Color _primaryColor = Color(0xFF005F87);

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

  void _closeFabMenu() {
    if (_showFabMenu) {
      setState(() => _showFabMenu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return FutureBuilder<InventoryRepository>(
      future: _repoFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Init error:\n${snapshot.error}')));
        }

        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final repo = snapshot.data!;

        final pages = [
          TodayPage(repo: repo, onRefresh: () => _refresh(repo)),
          InventoryPage(repo: repo, onRefresh: () => _refresh(repo)),
          // ✅ 传入 repo，实现闭环
          ShoppingListPage(repo: repo), 
          ImpactPage(repo: repo),
        ];

        // ✅ FAB 显示逻辑：
        // 0 (Today) & 1 (Inventory) -> 显示 FAB
        // 2 (Shopping) & 3 (Impact) -> 隐藏 FAB
        final bool fabEnabled = _currentIndex <= 1;

        return Scaffold(
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() {
                    _currentIndex = idx;
                    _showFabMenu = false;
                  });
                },
                children: pages,
              ),
              // 遮罩层
              if (fabEnabled)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_showFabMenu,
                    child: GestureDetector(
                      onTap: _closeFabMenu,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _showFabMenu ? 1.0 : 0.0,
                        curve: Curves.easeInOut,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                          child: Container(color: Colors.black.withOpacity(0.2)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: _primaryColor.withOpacity(0.15),
              labelTextStyle: MaterialStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              iconTheme: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return const IconThemeData(color: _primaryColor);
                }
                return IconThemeData(color: Colors.grey.shade600);
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) {
                _closeFabMenu();
                setState(() => _currentIndex = idx);
                _pageController.animateToPage(
                  idx,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuart,
                );
              },
              backgroundColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black12,
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
                  icon: Icon(Icons.shopping_cart_outlined),
                  selectedIcon: Icon(Icons.shopping_cart),
                  label: 'Shopping',
                ),
                NavigationDestination(
                  icon: Icon(Icons.eco_outlined),
                  selectedIcon: Icon(Icons.eco),
                  label: 'Impact',
                ),
              ],
            ),
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
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: 140,
          height: 280,
          child: Stack(
            alignment: Alignment.bottomRight,
            clipBehavior: Clip.none,
            children: [
              _FabActionButton(
                index: 0,
                icon: Icons.edit_note_rounded,
                label: 'Manual',
                visible: _showFabMenu,
                onTap: () => _navigateToAdd(repo, 0),
              ),
              _FabActionButton(
                index: 1,
                icon: Icons.camera_alt_rounded,
                label: 'Photo',
                visible: _showFabMenu,
                onTap: () => _navigateToAdd(repo, 1),
              ),
              _FabActionButton(
                index: 2,
                icon: Icons.mic_rounded,
                label: 'Voice',
                visible: _showFabMenu,
                onTap: () => _navigateToAdd(repo, 2),
              ),
              FloatingActionButton(
                heroTag: 'main_fab',
                onPressed: !enabled
                    ? null
                    : () => setState(() => _showFabMenu = !_showFabMenu),
                backgroundColor: _primaryColor,
                elevation: _showFabMenu ? 0 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedRotation(
                  turns: _showFabMenu ? 0.125 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: const Icon(
                    Icons.add,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAdd(InventoryRepository repo, int tabIndex) async {
    _closeFabMenu();
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
    const double fabSize = 56.0;
    const double gap = 16.0;
    final double bottomOffset = fabSize + gap + (index * (50 + gap));

    final duration = Duration(milliseconds: 200 + (index * 50));
    final curve = Curves.easeOutCubic;

    return AnimatedPositioned(
      duration: duration,
      curve: curve,
      right: 0,
      bottom: visible ? bottomOffset : 0,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 150 + (index * 50)),
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: duration,
          curve: curve,
          offset: visible ? Offset.zero : const Offset(0, 0.2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    // ✅ 修复：boxShadow 放在了 decoration 内部
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: FloatingActionButton(
                  heroTag: '${label}_fab',
                  onPressed: onTap,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF005F87),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}