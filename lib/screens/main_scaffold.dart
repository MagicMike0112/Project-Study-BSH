// lib/screens/main_scaffold.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
  late PageController _pageController;
  
  double _fabOpacity = 0.0; 

  static const Color _primaryColor = Color(0xFF005F87);


  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _pageController.addListener(_handleFabVisibility);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handleFabVisibility);
    _pageController.dispose();
    super.dispose();
  }

  void _handleFabVisibility() {
    if (!_pageController.hasClients || _pageController.page == null) return;
    final page = _pageController.page!;
    
    double newOpacity = 0.0;
    
    if (page < 1.0) {
      newOpacity = 0.0;
    } else if (page >= 1.0 && page < 2.0) {
      newOpacity = (1.0 - (page - 1.0)).clamp(0.0, 1.0);
    } else {
      newOpacity = 0.0;
    }

    if ((newOpacity - _fabOpacity).abs() > 0.01) {
      setState(() {
        _fabOpacity = newOpacity;
        if (_fabOpacity < 0.01 && _showFabMenu) {
          _showFabMenu = false;
        }
      });
    }
  }

  void _refresh() => setState(() {});

  void _closeFabMenu() {
    if (_showFabMenu) setState(() => _showFabMenu = false);
  }

  void _toggleFabMenu() {
    HapticFeedback.lightImpact();
    setState(() => _showFabMenu = !_showFabMenu);
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      _closeFabMenu();
      _pageController.jumpToPage(index);
    }
  }

  void showAppToast(String message, {VoidCallback? onUndo}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final toastBg = isDark ? const Color(0xFF1E1F24) : const Color(0xFF323232);
    final toastText = isDark ? Colors.white : Colors.white;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: toastBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          margin: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: toastText, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onUndo != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    onUndo();
                    messenger.hideCurrentSnackBar();
                  },
                  child: const Text(
                    'UNDO',
                    style: TextStyle(
                      color: Color(0xFF81D4FA),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    final repo = context.watch<InventoryRepository>();

    final hasUnreadActivity = repo.hasUnreadActivity;
    final pages = [
      TodayPageWrapper(repo: repo, onRefresh: _refresh),
      InventoryPageWrapper(
        repo: repo,
        onRefresh: _refresh,
        showSnackBar: (msg, {onUndo}) => showAppToast(msg, onUndo: onUndo),
      ),
      ShoppingListPageWrapper(repo: repo),
      ImpactPageWrapper(repo: repo),
    ];

    return Scaffold(
      extendBody: true,
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
              if (idx == 3) {
                repo.markActivitySeen();
              }
            },
            children: pages,
          ),

          if (_fabOpacity > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_showFabMenu,
                child: GestureDetector(
                  onTap: () {
                    _closeFabMenu();
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
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

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), 
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(isDark ? 0.08 : 0.65),
                        Colors.white.withOpacity(isDark ? 0.04 : 0.35),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(isDark ? 0.12 : 0.5), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Today'),
                      _buildNavItem(1, Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory'),
                      _buildNavItem(2, Icons.shopping_cart_outlined, Icons.shopping_cart, 'Shopping'),
                      _buildNavItem(3, Icons.eco_outlined, Icons.eco, 'Impact', showDot: hasUnreadActivity),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      floatingActionButton: Padding(
        // 抬高 FAB，避免与通知冲突
        padding: const EdgeInsets.only(bottom: 46),
        child: IgnorePointer(
          ignoring: _fabOpacity <= 0.01,
          child: Opacity(
            opacity: _fabOpacity,
            child: _buildExpandableFab(repo),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, {bool showDot = false}) {
    final isSelected = _currentIndex == index;
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isSelected ? 8 : 0),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor.withOpacity(0.15) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? _primaryColor : colors.onSurface.withOpacity(0.6),
                    size: 24,
                  ),
                  if (showDot)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _primaryColor,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableFab(InventoryRepository repo) {
    return SizedBox(
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
            onTap: _toggleFabMenu,
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
              child: const Icon(Icons.add, size: 32, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAdd(InventoryRepository repo, int tabIndex) async {
    _closeFabMenu();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodPage(repo: repo, initialTab: tabIndex),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const double fabSize = 56.0;
    const double gap = 16.0;
    final double bottomOffset = fabSize + gap + (index * (50 + gap));
    
    // 修改点：改为 Positioned (不再使用 AnimatedPositioned)，并移除 bottom 的位移动画逻辑
    return Positioned(
      right: 4,
      bottom: bottomOffset, // 固定位置，不再跳动
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut, // 建议使用 easeOut 让渐显更自然
        opacity: visible ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              BouncingButton(
                onTap: onTap,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
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
