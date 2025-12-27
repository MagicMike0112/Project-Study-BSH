// lib/screens/main_scaffold.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🟢 Added for Haptics
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

  void _toggleFabMenu() {
    // 🟢 触感反馈：轻微撞击感
    HapticFeedback.lightImpact();
    setState(() => _showFabMenu = !_showFabMenu);
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
          ShoppingListPage(repo: repo), 
          ImpactPage(repo: repo),
        ];

        final bool fabEnabled = _currentIndex <= 1;

        return Scaffold(
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(), // 保持 iOS 风格回弹
                onPageChanged: (idx) {
                  setState(() {
                    _currentIndex = idx;
                    _showFabMenu = false;
                  });
                },
                children: pages,
              ),
              
              // 遮罩层 (带模糊)
              if (fabEnabled)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_showFabMenu,
                    child: GestureDetector(
                      onTap: () {
                        _closeFabMenu();
                        HapticFeedback.selectionClick(); // 关闭时的轻微反馈
                      },
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        opacity: _showFabMenu ? 1.0 : 0.0,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), // 🟢 稍微增加模糊度，更有质感
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
              labelTextStyle: MaterialStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              iconTheme: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return const IconThemeData(color: _primaryColor, size: 26);
                }
                return IconThemeData(color: Colors.grey.shade500, size: 24);
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              height: 65, // 🟢 稍微调低高度，显得更紧凑
              onDestinationSelected: (idx) {
                if (_currentIndex != idx) {
                  // 🟢 触感反馈：类似 iOS Tab 切换的手感
                  HapticFeedback.selectionClick();
                  _closeFabMenu();
                  setState(() => _currentIndex = idx);
                  _pageController.animateToPage(
                    idx,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutQuart, // 更平滑的曲线
                  );
                }
              },
              backgroundColor: Colors.white,
              elevation: 0, // 去掉默认阴影，使用上方 border
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
              // 🟢 菜单项：使用 Spring 曲线和错峰延迟
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
              
              // 主 FAB
              // 🟢 增加 BouncingButton 包裹，按压有缩放效果
              BouncingButton(
                onTap: enabled ? _toggleFabMenu : () {},
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(18), // 🟢 方圆形更现代
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: AnimatedRotation(
                    turns: _showFabMenu ? 0.125 : 0, // 旋转 45度
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack, // 🟢 旋转带回弹
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
    // 计算底部距离：index 0 是最下面 (Manual)
    final double bottomOffset = fabSize + gap + (index * (50 + gap));

    // 🟢 动画时长错峰：离手最近的先出来
    final duration = Duration(milliseconds: 300 + (index * 100));
    
    // 🟢 使用 easeOutBack 产生类似弹簧弹出的效果
    final curve = Curves.easeOutBack;

    return AnimatedPositioned(
      duration: duration,
      curve: curve,
      right: 4, // 稍微对其中心
      bottom: visible ? bottomOffset : 0, // 从 FAB 底部弹出
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 200 + (index * 50)),
        opacity: visible ? 1 : 0,
        child: AnimatedScale(
          scale: visible ? 1.0 : 0.5, // 🟢 同时带有缩放效果
          duration: duration,
          curve: curve,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 标签
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
                    fontWeight: FontWeight.w700, // 加粗一点更清晰
                    color: Colors.black87,
                  ),
                ),
              ),
              
              // 按钮本体 - 使用 BouncingButton
              BouncingButton(
                onTap: onTap,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14), // 方圆形
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

// ================== Premium Animation Widgets ==================
// (这里复用之前的 BouncingButton 代码，确保此文件独立可用)

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
      upperBound: 0.08, // 缩放幅度
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
          HapticFeedback.lightImpact(); // 🟢 震动反馈
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