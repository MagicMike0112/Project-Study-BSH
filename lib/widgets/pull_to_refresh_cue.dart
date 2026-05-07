import 'dart:math' as math;

import 'package:flutter/material.dart';

class PullToRefreshCue extends StatelessWidget {
  final double progress;
  final bool armed;
  final Color color;
  final String hintText;
  final String releaseText;

  const PullToRefreshCue({
    super.key,
    required this.progress,
    required this.armed,
    required this.color,
    this.hintText = 'Pull to refresh',
    this.releaseText = 'Release to refresh',
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.2);
    final visible = p > 0.02;
    if (!visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final opacity = (p <= 1 ? p : 1).toDouble();
    final eased = Curves.easeOutCubic.transform(opacity);
    final y = -24 + (eased * 28);
    final readiness = p.clamp(0.0, 1.0).toDouble();
    final statusColor = armed ? const Color(0xFF16A34A) : color;
    final surface = theme.cardColor;
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.82);
    final assistText = armed ? releaseText : hintText;
    final percentText = '${(readiness * 100).round()}%';

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(0, y),
            child: Opacity(
              opacity: eased,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                scale: armed ? 1.03 : 1.0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 182),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: armed ? 0.28 : 0.16),
                        blurRadius: armed ? 20 : 12,
                        spreadRadius: armed ? 1.2 : 0.2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 140),
                                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                                child: armed
                                    ? Icon(
                                        Icons.check_rounded,
                                        key: const ValueKey('armed'),
                                        size: 14,
                                        color: statusColor,
                                      )
                                    : Transform.rotate(
                                        key: const ValueKey('pulling'),
                                        angle: math.pi * (1 - readiness),
                                        child: Icon(
                                          Icons.arrow_downward_rounded,
                                          size: 14,
                                          color: statusColor,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            assistText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            percentText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          width: 160,
                          height: 4,
                          child: Stack(
                            children: [
                              Container(color: statusColor.withValues(alpha: 0.16)),
                              FractionallySizedBox(
                                widthFactor: readiness,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        statusColor.withValues(alpha: 0.8),
                                        statusColor,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
