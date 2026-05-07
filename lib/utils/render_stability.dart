import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized rendering guardrails for devices that are sensitive to
/// heavyweight effects (BackdropFilter / large blur sigma / layered opacity).
class RenderStability {
  const RenderStability._();

  /// Keep this `true` for production stability on Android class devices.
  static const bool gpuConservativeMode = true;

  static bool shouldUseHeavyEffects(BuildContext context) {
    if (!gpuConservativeMode) return true;
    if (kIsWeb) return true;
    final platform = Theme.of(context).platform;
    return platform != TargetPlatform.android;
  }

  static double blurSigma(BuildContext context, double heavy, {double light = 0}) {
    return shouldUseHeavyEffects(context) ? heavy : light;
  }
}

