// lib/screens/today_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Haptics
import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../widgets/food_card.dart';
import 'select_ingredients_page.dart';

class TodayPage extends StatelessWidget {
  final InventoryRepository repo;
  final VoidCallback onRefresh;

  const TodayPage({
    super.key,
    required this.repo,
    required this.onRefresh,
  });

  static const Color _primaryBlue = Color(0xFF0E7AA8);
  static const Color _surfaceColor = Color(0xFFF8F9FC);

  // 🟢 辅助方法：显示贴底的自定义通知
  void _showBottomSnackBar(BuildContext context, String message, {VoidCallback? onUndo}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar() // 立即清除上一个
      ..showSnackBar(
        SnackBar(
          // 🟢 贴底关键设置
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 3),
          
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF323232),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            margin: const EdgeInsets.only(bottom: 20), // 离底部 20
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onUndo != null)
                  GestureDetector(
                    onTap: () {
                      onUndo();
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text(
                        'UNDO',
                        style: TextStyle(
                          color: Color(0xFF81D4FA),
                          fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    // 监听 Repo 变化
    return AnimatedBuilder(
      animation: repo,
      builder: (context, child) {
        final expiring = repo.getExpiringItems(3);

        return Scaffold(
          backgroundColor: _surfaceColor,
          appBar: AppBar(
            title: const Text(
              'Smart Food Home',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            centerTitle: false,
            backgroundColor: _surfaceColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: Colors.black87,
            systemOverlayStyle: SystemUiOverlayStyle.dark, 
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // 1. Impact Summary
              FadeInSlide(
                index: 0,
                child: _buildImpactSummary(context),
              ),
              const SizedBox(height: 24),

              // 2. AI Chef Button
              FadeInSlide(
                index: 1,
                child: BouncingButton(
                  onTap: () => _showAiRecipeFlow(context, expiring),
                  child: _buildAiButton(context), 
                ),
              ),
              const SizedBox(height: 32),

              // 3. Expiring Header
              FadeInSlide(
                index: 2,
                child: _buildSectionHeader(context, expiring.length),
              ),
              const SizedBox(height: 16),

              // 4. Expiring List
              if (expiring.isEmpty)
                FadeInSlide(
                  index: 3,
                  child: _buildEmptyState(context),
                )
              else
                ...expiring.asMap().entries.map(
                  (entry) => FadeInSlide(
                    index: 3 + entry.key,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FoodCard(
                        item: entry.value,
                        leading: _buildInventoryStyleLeading(entry.value),
                        onAction: (action) async {
                          HapticFeedback.mediumImpact();
                          
                          final item = entry.value;
                          final oldStatus = item.status;
                          await repo.recordImpactForAction(item, action);

                          FoodStatus? newStatus;
                          if (action == 'eat' || action == 'pet') {
                            newStatus = FoodStatus.consumed;
                          } else if (action == 'trash') {
                            newStatus = FoodStatus.discarded;
                          }

                          if (newStatus != null) {
                            await repo.updateStatus(item.id, newStatus);
                          }

                          if (action == 'pet' && !repo.hasShownPetWarning) {
                            await repo.markPetWarningShown();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  behavior: SnackBarBehavior.fixed, // 警告信息保持默认样式更醒目，或者是你也可以统一
                                  content: Text('Please ensure the food is safe for your pet!'),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          }

                          if (newStatus != null) {
                            // 🟢 使用新的贴底通知
                            _showBottomSnackBar(
                              context,
                              _undoLabelForAction(action, item.name),
                              onUndo: () async {
                                HapticFeedback.selectionClick();
                                await repo.updateStatus(item.id, oldStatus);
                                onRefresh(); // 这一步其实不需要了，因为 AnimatedBuilder 会自动刷新，但留着也没事
                              },
                            );
                          }
                          // onRefresh(); // 同样，AnimatedBuilder 会处理
                        },
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }

  Future<void> _showAiRecipeFlow(BuildContext context, List<FoodItem> expiringItems) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectIngredientsPage(
          repo: repo,
          preselectedExpiring: expiringItems,
        ),
      ),
    );
    if (changed == true) onRefresh();
  }

  Widget _buildInventoryStyleLeading(FoodItem item) {
    final leading = _leadingIcon(item);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: leading.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(leading.icon, color: leading.color, size: 22),
    );
  }

  _Leading _leadingIcon(FoodItem item) {
    switch (item.location) {
      case StorageLocation.fridge:
        return const _Leading(Icons.kitchen_rounded, Color(0xFF005F87));
      case StorageLocation.freezer:
        return const _Leading(Icons.ac_unit_rounded, Color(0xFF3F51B5));
      case StorageLocation.pantry:
        return const _Leading(Icons.shelves, Color(0xFF795548));
    }
  }

  Widget _buildImpactSummary(BuildContext context) {
    final saved = repo.getSavedCount();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.eco_rounded, color: _primaryBlue, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact this week',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep it up!',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$saved',
                style: const TextStyle(
                  color: _primaryBlue,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              Text(
                saved == 1 ? 'item saved' : 'items saved',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A3F6B).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF60A5FA), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Chef',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Cook with expiring items',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, int count) {
    return Row(
      children: [
        Text(
          'Expiring Soon',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: -0.5,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEAEA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.green, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your fridge is fresh and organized.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _undoLabelForAction(String action, String name) {
    switch (action) {
      case 'eat':
        return 'Cooked "$name"';
      case 'pet':
        return 'Fed "$name" to pet';
      case 'trash':
        return 'Discarded "$name"';
      default:
        return 'Updated "$name"';
    }
  }
}

class _Leading {
  final IconData icon;
  final Color color;
  const _Leading(this.icon, this.color);
}

// ================== Shared Animation Widgets ==================

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
      upperBound: 0.05,
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

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int index; 
  final Duration duration;

  const FadeInSlide({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(curve);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

    final delay = widget.index * 50; 
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _offsetAnim,
        child: widget.child,
      ),
    );
  }
}