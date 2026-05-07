import 'dart:math' as math;

import 'package:flutter/material.dart';

Route<T> topRightRevealRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInQuart,
      );
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
          reverseCurve: Curves.easeInQuart,
        ),
      );
      return AnimatedBuilder(
        animation: curve,
        builder: (context, _) {
          return ClipPath(
            clipper: _TopRightRevealClipper(progress: curve.value),
            child: FadeTransition(opacity: fade, child: child),
          );
        },
      );
    },
  );
}

class _TopRightRevealClipper extends CustomClipper<Path> {
  final double progress;

  const _TopRightRevealClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final safeProgress = progress.clamp(0.0, 1.0);
    final center = Offset(size.width, 0);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * safeProgress;
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _TopRightRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
