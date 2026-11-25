import 'dart:ui';

import 'package:droplet_core/droplet_core.dart';

/// Droplet Light : la source de lumière suit le doigt, lentement.
///
/// Un ressort lent et très amorti évite que les reflets sautent : la lumière
/// glisse vers sa nouvelle position comme un reflet sur l'eau.
class LightFollower {
  LightFollower(Offset initial)
      : _spring = Spring2D(
          position: initial,
          stiffness: MotionTokens.springLight.stiffness,
          dampingRatio: MotionTokens.springLight.damping,
        );

  final Spring2D _spring;

  Offset get position => _spring.position;

  void follow(Offset target) => _spring.target = target;

  void step(double dt) => _spring.step(dt);
}
