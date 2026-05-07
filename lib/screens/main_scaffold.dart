// lib/screens/main_scaffold.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import '../utils/app_haptics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/render_stability.dart';

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
  bool _isTabAnimating = false;
  late final ValueNotifier<double> _fabOpacity;

  // Updated to match the new design language (Primary Blue)
  static const Color _primaryColor = Color(0xFF135bec);
  // Updated dark background for glass effect consistency
  static const Color _glassDarkColor = Color(0xFF101622);


  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fabOpacity = ValueNotifier<double>(0.0);
    _pageController.addListener(_handleFabVisibility);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handleFabVisibility);
    _pageController.dispose();
    _fabOpacity.dispose();
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

    if ((newOpacity - _fabOpacity.value).abs() > 0.01) {
      _fabOpacity.value = newOpacity;
      if (_fabOpacity.value < 0.01 && _showFabMenu) {
        setState(() => _showFabMenu = false);
      }
    }
  }

  void _refresh() => setState(() {});

  void _closeFabMenu() {
    if (_showFabMenu) setState(() => _showFabMenu = false);
  }

  void _toggleFabMenu() {
    AppHaptics.selection();
    setState(() => _showFabMenu = !_showFabMenu);
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index || _isTabAnimating) return;
    AppHaptics.selection();
    _closeFabMenu();
    final distance = (index - _currentIndex).abs();
    if (distance > 1) {
      _pageController.jumpToPage(index);
      return;
    }
    _isTabAnimating = true;
    _pageController
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubicEmphasized,
        )
        .whenComplete(() => _isTabAnimating = false);
  }

  void showAppToast(String message, {VoidCallback? onUndo}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
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
                  child: Text(
                    l10n.undo,
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final useHeavyEffects = RenderStability.shouldUseHeavyEffects(context);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    final repo = context.read<InventoryRepository>();

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            allowImplicitScrolling: true,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
                _showFabMenu = false;
              });
              if (idx == 3) {
                repo.markActivitySeen();
              }
            },
            children: [
              TodayPageWrapper(
                repo: repo,
                onRefresh: _refresh,
                isActive: _currentIndex == 0,
              ),
              InventoryPageWrapper(
                repo: repo,
                onRefresh: _refresh,
                showSnackBar: (msg, {onUndo}) => showAppToast(msg, onUndo: onUndo),
                isActive: _currentIndex == 1,
              ),
              ShoppingListPageWrapper(
                repo: repo,
                isActive: _currentIndex == 2,
              ),
              ImpactPageWrapper(
                repo: repo,
                isActive: _currentIndex == 3,
              ),
            ],
          ),

          ValueListenableBuilder<double>(
            valueListenable: _fabOpacity,
            builder: (context, opacity, child) {
              if (opacity <= 0.01) return const SizedBox.shrink();
              return Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showFabMenu,
                  child: GestureDetector(
                    onTap: () {
                      _closeFabMenu();
                      AppHaptics.selection();
                    },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      opacity: _showFabMenu ? 1.0 : 0.0,
                      child: useHeavyEffects
                          ? BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                              child: Container(color: Colors.black.withValues(alpha: 0.2)),
                            )
                          : Container(color: Colors.black.withValues(alpha: 0.18)),
                    ),
                  ),
                ),
              );
            },
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
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: useHeavyEffects
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: _buildBottomBarContent(context, l10n, isDark),
                    )
                  : _buildBottomBarContent(context, l10n, isDark),
            ),
          ),
        ),
      ),

      floatingActionButton: Padding(
        // NOTE: legacy comment cleaned.
        padding: const EdgeInsets.only(bottom: 46),
        child: ValueListenableBuilder<double>(
          valueListenable: _fabOpacity,
          builder: (context, opacity, child) {
            return IgnorePointer(
              ignoring: opacity <= 0.01,
              child: Opacity(
                opacity: opacity,
                child: _buildExpandableFab(repo),
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBottomBarContent(BuildContext context, AppLocalizations l10n, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _glassDarkColor.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.9),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, l10n.navToday),
          _buildNavItem(1, Icons.inventory_2_outlined, Icons.inventory_2, l10n.navInventory),
          _buildNavItem(2, Icons.shopping_cart_outlined, Icons.shopping_cart, l10n.navShopping),
          Selector<InventoryRepository, bool>(
            selector: (_, repo) => repo.hasUnreadActivity,
            builder: (_, hasUnreadActivity, __) {
              return _buildNavItem(
                3,
                Icons.eco_outlined,
                Icons.eco,
                l10n.navImpact,
                showDot: hasUnreadActivity,
              );
            },
          ),
        ],
      ),
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
                color: isSelected ? _primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? _primaryColor : colors.onSurface.withValues(alpha: 0.6),
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
    final l10n = AppLocalizations.of(context);
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
            label: l10n?.addFoodTabManual ?? 'Manual',
            visible: _showFabMenu,
            onTap: () => _navigateToAdd(repo, 0),
          ),
          _FabActionButton(
            index: 1,
            icon: Icons.camera_alt_rounded,
            label: l10n?.addFoodTabScan ?? 'Scan',
            visible: _showFabMenu,
            onTap: () => _navigateToAdd(repo, 1),
          ),
          _FabActionButton(
            index: 2,
            icon: Icons.mic_rounded,
            label: l10n?.addFoodTabVoice ?? 'Voice',
            visible: _showFabMenu,
            onTap: () => _navigateToAdd(repo, 2),
          ),
          BouncingButton(
            onTap: _toggleFabMenu,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                // Applied Gradient from new design
                gradient: const LinearGradient(
                  colors: [_primaryColor, Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.4),
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
    
    // Positioned (fixed, no jump)
    return Positioned(
      right: 4,
      bottom: bottomOffset, 
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut, 
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
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
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
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // Updated icon color to match new primary
                  child: Icon(icon, size: 22, color: const Color(0xFF135bec)),
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
          AppHaptics.selection();
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







