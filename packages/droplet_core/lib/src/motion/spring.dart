import 'dart:math' as math;
import 'dart:ui';

/// Ressort amorti en deux dimensions, intégré à pas fixe.
///
/// Droplet Motion n'utilise pas de courbes à durée fixe pour ce que le doigt
/// déplace : la matière suit sa cible avec un ressort, comme un liquide qui a
/// une masse. `stiffness` règle la vivacité, `dampingRatio` le rebond
/// (1 = aucun rebond, moins de 1 = léger dépassement).
class Spring2D {
  Spring2D({
    required Offset position,
    this.stiffness = 180,
    this.dampingRatio = 0.72,
  })  : _position = position,
        target = position;

  double stiffness;
  double dampingRatio;
  Offset target;
  Offset _position;
  Offset _velocity = Offset.zero;

  Offset get position => _position;
  Offset get velocity => _velocity;

  bool get isAtRest =>
      (_position - target).distance < 0.05 && _velocity.distance < 0.05;

  /// Avance de `dt` secondes. Sous-pas de 4 ms pour rester stable même si une image est lente.
  void step(double dt) {
    var remaining = dt.clamp(0.0, 0.1);
    final damping = 2 * dampingRatio * math.sqrt(stiffness);
    while (remaining > 0) {
      final h = math.min(remaining, 0.004);
      final force = (target - _position) * stiffness - _velocity * damping;
      _velocity += force * h;
      _position += _velocity * h;
      remaining -= h;
    }
  }

  void snap(Offset value) {
    _position = value;
    target = value;
    _velocity = Offset.zero;
  }
}

/// Ressort scalaire, pour une intensité (appui, ouverture).
class Spring1D {
  Spring1D({double value = 0, this.stiffness = 220, this.dampingRatio = 0.8})
      : _value = value,
        target = value;

  double stiffness;
  double dampingRatio;
  double target;
  double _value;
  double _velocity = 0;

  double get value => _value;

  void step(double dt) {
    var remaining = dt.clamp(0.0, 0.1);
    final damping = 2 * dampingRatio * math.sqrt(stiffness);
    while (remaining > 0) {
      final h = math.min(remaining, 0.004);
      final force = (target - _value) * stiffness - _velocity * damping;
      _velocity += force * h;
      _value += _velocity * h;
      remaining -= h;
    }
  }
}
