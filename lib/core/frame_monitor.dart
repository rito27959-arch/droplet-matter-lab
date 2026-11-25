import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Mesure les vraies durées d'image rapportées par le moteur (construction +
/// rastérisation), sur une fenêtre glissante. C'est la mesure à lire sur un vrai
/// téléphone : dans un navigateur sans GPU, les chiffres ne veulent rien dire.
class FrameMonitor extends ChangeNotifier {
  FrameMonitor({this.window = 90, this.budget = const Duration(microseconds: 16667)});

  final int window;
  final Duration budget;
  final List<double> _totalsMs = [];
  int _missed = 0;
  bool _attached = false;

  double get averageMs => _totalsMs.isEmpty ? 0 : _totalsMs.reduce((a, b) => a + b) / _totalsMs.length;

  double get worstMs => _totalsMs.isEmpty ? 0 : _totalsMs.reduce((a, b) => a > b ? a : b);

  /// Part des images de la fenêtre qui dépassent le budget.
  double get missRatio => _totalsMs.isEmpty ? 0 : _missed / _totalsMs.length;

  double get estimatedFps => averageMs <= 0 ? 0 : (1000 / averageMs).clamp(0, 120).toDouble();

  void attach() {
    if (_attached) return;
    _attached = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      _totalsMs.add(ms);
      if (t.totalSpan > budget) _missed++;
      if (_totalsMs.length > window) {
        final removed = _totalsMs.removeAt(0);
        if (removed > budget.inMicroseconds / 1000.0) _missed--;
      }
    }
    notifyListeners();
  }

  void reset() {
    _totalsMs.clear();
    _missed = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
