import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  const BouncingButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }
    return GestureDetector(
      onTapDown: (_) {
        if (widget.enabled) {
          _controller!.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (widget.enabled) {
          _controller!.reverse();
          widget.onTap?.call();
        }
      },
      onTapCancel: () {
        if (widget.enabled) _controller!.reverse();
      },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - _controller!.value,
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
  AnimationController? _controller;
  Animation<Offset>? _offsetAnim;
  Animation<double>? _fadeAnim;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    final controller = AnimationController(vsync: this, duration: widget.duration);
    _controller = controller;
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(curve);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    final delay = widget.index * 50;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller?.forward();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fadeAnim!,
      child: SlideTransition(position: _offsetAnim!, child: widget.child),
    );
  }
}
