import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// État brut du pointeur, mis à jour sans reconstruire de widget.
class PointerState {
  Offset position = Offset.zero;
  bool hasPosition = false;
  bool pressed = false;

  /// Vitesse lissée, en pixels par seconde.
  Offset velocity = Offset.zero;

  /// Pression rapportée par l'écran (1 si l'appareil ne la mesure pas).
  double pressure = 1;
}

/// Capte le toucher, la souris et le glissement sur toute sa surface.
///
/// Les expériences lisent `state` à chaque image ; aucune reconstruction n'a
/// lieu pendant un geste, ce qui garde la réponse dans la même image.
class PointerField extends StatefulWidget {
  const PointerField({super.key, required this.state, required this.child});

  final PointerState state;
  final Widget child;

  @override
  State<PointerField> createState() => _PointerFieldState();
}

class _PointerFieldState extends State<PointerField> {
  Duration? _lastTime;

  void _update(PointerEvent e) {
    final s = widget.state;
    if (s.hasPosition && _lastTime != null) {
      final dt = (e.timeStamp - _lastTime!).inMicroseconds / 1e6;
      if (dt > 0) {
        final raw = (e.localPosition - s.position) / dt;
        s.velocity = Offset.lerp(s.velocity, raw, 0.35)!;
      }
    }
    s.position = e.localPosition;
    s.hasPosition = true;
    s.pressure = e.pressureMax > e.pressureMin && e.pressure > 0 ? e.pressure.clamp(0.2, 1.0).toDouble() : 1;
    _lastTime = e.timeStamp;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _update(e);
        widget.state.pressed = true;
      },
      onPointerMove: _update,
      onPointerHover: _update,
      onPointerUp: (e) {
        widget.state.pressed = false;
        _lastTime = null;
      },
      onPointerCancel: (e) {
        widget.state.pressed = false;
        _lastTime = null;
      },
      child: widget.child,
    );
  }
}
