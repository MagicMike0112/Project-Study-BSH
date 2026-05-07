import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight frame profiler for local performance checks.
///
/// Enable with:
/// `flutter run --profile --dart-define=ENABLE_FRAME_PROFILE=true`
class AppFrameProfiler {
  static const bool _enabled =
      bool.fromEnvironment('ENABLE_FRAME_PROFILE', defaultValue: false);
  static const int _sampleWindow = 90;
  static bool _installed = false;
  static final List<double> _uiMs = <double>[];
  static final List<double> _rasterMs = <double>[];

  static void maybeInstall() {
    if (!_enabled || _installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    debugPrint('[Perf] Frame profiler enabled (window=$_sampleWindow)');
  }

  static void _onFrameTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _uiMs.add(_toMs(t.buildDuration));
      _rasterMs.add(_toMs(t.rasterDuration));
    }
    if (_uiMs.length < _sampleWindow) return;

    final uiAvg = _avg(_uiMs);
    final rasterAvg = _avg(_rasterMs);
    final uiP95 = _p95(_uiMs);
    final rasterP95 = _p95(_rasterMs);
    final over16 = _jankPercent(_uiMs, _rasterMs, 16.6);
    final over33 = _jankPercent(_uiMs, _rasterMs, 33.3);

    debugPrint(
      '[Perf] avg(ui=${uiAvg.toStringAsFixed(1)}ms raster=${rasterAvg.toStringAsFixed(1)}ms) '
      'p95(ui=${uiP95.toStringAsFixed(1)}ms raster=${rasterP95.toStringAsFixed(1)}ms) '
      'jank>16.6=${over16.toStringAsFixed(1)}% jank>33.3=${over33.toStringAsFixed(1)}%',
    );

    _uiMs.clear();
    _rasterMs.clear();
  }

  static double _toMs(Duration d) => d.inMicroseconds / 1000.0;

  static double _avg(List<double> values) {
    if (values.isEmpty) return 0;
    final sum = values.fold<double>(0, (acc, v) => acc + v);
    return sum / values.length;
  }

  static double _p95(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final index = math.max(0, (sorted.length * 0.95).ceil() - 1);
    return sorted[index];
  }

  static double _jankPercent(
    List<double> ui,
    List<double> raster,
    double thresholdMs,
  ) {
    if (ui.isEmpty || raster.isEmpty) return 0;
    final len = math.min(ui.length, raster.length);
    var janky = 0;
    for (var i = 0; i < len; i++) {
      if (ui[i] > thresholdMs || raster[i] > thresholdMs) {
        janky++;
      }
    }
    return (janky / len) * 100;
  }
}
