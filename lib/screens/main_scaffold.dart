// lib/screens/main_scaffold.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // 🟢 引入 Provider

import '../repositories/inventory_repository.dart';
import 'today_page.dart';
import 'inventory_page.dart'; // 这里面包含了 InventoryPageWrapper
import 'impact_page.dart';
import 'add_food_page.dart';
import 'shopping_list_page.dart';
import 'account_page.dart'; // 确保引入 AccountPage

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
  late PageController _pageController;

  static const Color _primaryColor = Color(0xFF005F87);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  void _closeFabMenu() {
    if (_showFabMenu) {
      setState(() => _showFabMenu = false);
    }
  }

  void _toggleFabMenu() {
    HapticFeedback.lightImpact();
    setState(() => _showFabMenu = !_showFabMenu);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // 🟢 修复 1: 直接从 Provider 获取已经在 main.dart 初始化好的单例 Repo
    // 这样整个 App 共享同一个数据源，避免重复初始化导致的 bug
    final repo = context.watch<InventoryRepository>();

    final pages = [
      TodayPage(repo: repo, onRefresh: _refresh),
      
      // 🟢 修复 2: 使用 Wrapper 包裹，确保 ShowCaseWidget 存在
      InventoryPageWrapper(repo: repo, onRefresh: _refresh),
      
      ShoppingListPage(repo: repo),
      
      // Impact Page
      ImpactPage(repo: repo),

      // 🟢 补充: 如果你想把 Account 放在 Tab 里，可以加在这里，或者保持现状
      // 目前看起来 Account 是通过 ProfileAvatarButton 进入的，所以这里只需 4 个 Tab
    ];

    // FAB 只在 Today 和 Inventory 页面显示
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
          
          // FAB 展开时的遮罩层
          if (fabEnabled)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_showFabMenu,
                child: GestureDetector(
                  onTap: () {
                    _closeFabMenu();
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    opacity: _showFabMenu ? 1.0 : 0.0,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
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
          indicatorColor: _primaryColor.withOpacity(0.1),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _primaryColor, size: 26);
            }
            return IconThemeData(color: Colors.grey.shade500, size: 24);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          height: 65,
          onDestinationSelected: (idx) {
            if (_currentIndex != idx) {
              HapticFeedback.selectionClick();
              _closeFabMenu();
              setState(() => _currentIndex = idx);
              _pageController.animateToPage(
                idx,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutQuart,
              );
            }
          },
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
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
              
              BouncingButton(
                onTap: enabled ? _toggleFabMenu : () {},
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: AnimatedRotation(
                    turns: _showFabMenu ? 0.125 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: const Icon(
                      Icons.add,
                      size: 32,
                      color: Colors.white,
                    ),
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
    _refresh();
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
    final duration = Duration(milliseconds: 300 + (index * 100));
    const curve = Curves.easeOutBack;

    return AnimatedPositioned(
      duration: duration,
      curve: curve,
      right: 4,
      bottom: visible ? bottomOffset : 0,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 200 + (index * 50)),
        opacity: visible ? 1 : 0,
        child: AnimatedScale(
          scale: visible ? 1.0 : 0.5,
          duration: duration,
          curve: curve,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              BouncingButton(
                onTap: onTap,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 22, color: const Color(0xFF005F87)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 复用的 BouncingButton
class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  const BouncingButton({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.enabled) {
          _controller.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (widget.enabled) {
          _controller.reverse();
          widget.onTap();
        }
      },
      onTapCancel: () {
        if (widget.enabled) _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - _controller.value,
          child: widget.child,
        ),
      ),
    );
  }
}