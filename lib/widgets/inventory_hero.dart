import 'dart:ui'; // NOTE: legacy comment cleaned.
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
    // NOTE: legacy comment cleaned.
    final gradientColors = [
      const Color(0xFF002E4D), // Deep Navy
      const Color(0xFF005F7F), // Mid Petrol
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        // NOTE: legacy comment cleaned.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        // NOTE: legacy comment cleaned.
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002E4D).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        children: [
          // NOTE: legacy comment cleaned.
          Positioned(
              right: -40, top: -40, child: _GlassCircle(size: 180, opacity: 0.08)),
          Positioned(
              left: -30, bottom: -60, child: _GlassCircle(size: 200, opacity: 0.06)),

          // NOTE: legacy comment cleaned.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.15), // NOTE: legacy comment cleaned.
                    Colors.white.withValues(alpha: 0.0),  // NOTE: legacy comment cleaned.
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
                // NOTE: legacy comment cleaned.
                Column(
                  children: [
                    Text(
                      'Total Items',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF81D4FA).withValues(alpha: 0.9), // NOTE: legacy comment cleaned.
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // NOTE: legacy comment cleaned.
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15), // NOTE: legacy comment cleaned.
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                color: Colors.white.withValues(alpha: 0.6),
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
      color: Colors.white.withValues(alpha: 0.1),
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
        // NOTE: legacy comment cleaned.
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: opacity * 2),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}


