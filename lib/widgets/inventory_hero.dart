import 'dart:ui'; // 必须引入，用于 BackdropFilter (如果需要背景模糊)
import 'package:flutter/material.dart';

class InventoryHeroCard extends StatelessWidget {
  final int total;
  final int fridge;
  final int freezer;
  final int pantry;

  const InventoryHeroCard({
    super.key,
    required this.total,
    required this.fridge,
    required this.freezer,
    required this.pantry,
  });

  @override
  Widget build(BuildContext context) {
    // BSH 风格渐变
    final gradientColors = [
      const Color(0xFF002E4D), // Deep Navy
      const Color(0xFF005F7F), // Mid Petrol
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        // 1. 背景渐变
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        // 2. 更有深度的阴影
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002E4D).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        children: [
          // 装饰性光斑 (更柔和)
          Positioned(
              right: -40, top: -40, child: _GlassCircle(size: 180, opacity: 0.08)),
          Positioned(
              left: -30, bottom: -60, child: _GlassCircle(size: 200, opacity: 0.06)),

          // 3. 玻璃质感边框 (Overlay)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15), // 左上角高光
                    Colors.white.withOpacity(0.0),  // 右下角透明
                  ],
                  stops: const [0.0, 0.4],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                // Total Count 区域
                Column(
                  children: [
                    Text(
                      'Total Items',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF81D4FA).withOpacity(0.9), // 浅蓝灰色文字
                        letterSpacing: 1.2,
                        //uppercase: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2,
                        fontFamily: 'Roboto', // 推荐使用稍微机械感的字体
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // 统计数据栏
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15), // 内部加深，增加对比度
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(icon: Icons.kitchen_rounded, label: 'Fridge', count: fridge),
                      _VerticalDivider(),
                      _StatColumn(icon: Icons.ac_unit_rounded, label: 'Freezer', count: freezer),
                      _VerticalDivider(),
                      _StatColumn(icon: Icons.shelves, label: 'Pantry', count: pantry),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const _StatColumn({required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4DD0E1), size: 24), // BSH Cyan Accent
        const SizedBox(height: 6),
        Text('$count',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withOpacity(0.1),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _GlassCircle({required this.size, this.opacity = 0.05});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 使用径向渐变让光圈更自然
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity * 2),
            Colors.white.withOpacity(0),
          ],
        ),
      ),
    );
  }
}