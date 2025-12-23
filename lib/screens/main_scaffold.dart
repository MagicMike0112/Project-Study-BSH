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

  // 定义主色调，方便统一管理 UI
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
                style: const TextStyle(color: Colors.red),
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
            physics: const NeverScrollableScrollPhysics(), // 建议禁止滑动切换，避免手势冲突
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
                _showFabMenu = false;
              });
            },
            children: pages,
          ),

          // 使用 Theme 优化 NavigationBar 的视觉体验
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: _primaryColor.withOpacity(0.15), // 选中时的浅色背景胶囊
              labelTextStyle: MaterialStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              iconTheme: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return const IconThemeData(color: _primaryColor); // 选中图标颜色
                }
                return IconThemeData(color: Colors.grey.shade600); // 未选中图标颜色
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) {
                setState(() {
                  _currentIndex = idx;
                  _showFabMenu = false;
                });
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
          ),

          floatingActionButton: _buildExpandableFab(repo, fabEnabled),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  Widget _buildExpandableFab(InventoryRepository repo, bool enabled) {
    // FAB 展开时的高度
    const double expandedHeight = 280;

    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: 140, // 稍微加宽一点，防止 Label 换行
          height: expandedHeight,
          child: Stack(
            alignment: Alignment.bottomRight,
            clipBehavior: Clip.none,
            children: [
              // 点击遮罩 (可选：如果想点击空白处关闭菜单，可以在这里加一个全屏透明 GestureDetector，但由于是在 Fab 区域内，这里省略)
              
              // 菜单项 1
              _FabActionButton(
                index: 0,
                icon: Icons.edit_note_rounded,
                label: 'Manual',
                visible: _showFabMenu,
                onTap: () => _navigateToAdd(repo, 0),
              ),
              // 菜单项 2
              _FabActionButton(
                index: 1,
                icon: Icons.camera_alt_rounded,
                label: 'Photo',
                visible: _showFabMenu,
                onTap: () => _navigateToAdd(repo, 1),
              ),
              // 菜单项 3
              _FabActionButton(
                index: 2,
                icon: Icons.mic_rounded,
                label: 'Voice',
                visible: _showFabMenu,
                onTap: () => _navigateToAdd(repo, 2),
              ),

              // 主 FAB 按钮
              FloatingActionButton(
                heroTag: 'main_fab',
                onPressed: !enabled
                    ? null
                    : () => setState(() => _showFabMenu = !_showFabMenu),
                backgroundColor: _primaryColor,
                elevation: _showFabMenu ? 2 : 4, // 展开时降低一点阴影
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), // 方圆形看起来更现代
                ),
                child: AnimatedRotation(
                  turns: _showFabMenu ? 0.125 : 0, // 旋转 45度 (0.125 * 360)
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
    const double fabSize = 56.0; // 标准 FAB 高度
    const double gap = 16.0; // 按钮间距
    final double bottomOffset = fabSize + gap + (index * (50 + gap)); // 动态计算位置

    final duration = Duration(milliseconds: 200 + (index * 50));
    final curve = Curves.easeOutCubic;

    return AnimatedPositioned(
      duration: duration,
      curve: curve,
      right: 0, // 稍微靠右对齐
      bottom: visible ? bottomOffset : 0,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 150 + (index * 50)),
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: duration,
          curve: curve,
          offset: visible ? Offset.zero : const Offset(0, 0.2), // 稍微带点向上滑动的效果
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 文本标签
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
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
              // 小圆按钮
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