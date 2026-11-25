import 'package:flutter/material.dart';

import 'package:droplet_core/droplet_core.dart';
import 'package:droplet_glass/droplet_glass.dart';
import 'common_logic.dart';
import 'experiment.dart';

/// Expérience 05 — la matière qui répond au toucher.
///
/// Trois réponses, chacune pilotée par un ressort : la goutte suit le doigt
/// (position), s'étire dans le sens du geste (vitesse), et se tend vers le
/// point d'appui (intensité de l'appui, pression réelle si l'écran la mesure).
class InteractiveMatter extends ExperimentLogic {
  @override
  int get number => 5;
  @override
  String get title => 'Matière interactive';
  @override
  String get summary =>
      'Touchez, glissez, lâchez. La goutte suit le doigt avec un ressort, s’étire dans le sens du geste et se tend vers le point d’appui.';
  @override
  String get shaderAsset => ShaderLibrary.interactiveMatter;

  Spring2D? _center;
  final Spring1D _press = Spring1D(
    stiffness: MotionTokens.springPress.stiffness,
    dampingRatio: MotionTokens.springPress.damping,
  );
  Offset _velocity = Offset.zero;

  @override
  void tick(FrameContext f) {
    final home = Offset(f.size.width / 2, f.size.height * 0.5);
    final c = _center ??= Spring2D(
      position: home,
      stiffness: MotionTokens.springFollow.stiffness,
      dampingRatio: MotionTokens.springFollow.damping,
    );
    c.target = f.pointer.pressed ? f.pointer.position : home;
    c.step(f.dt);
    _press.target = f.pointer.pressed ? f.pointer.pressure : 0;
    _press.step(f.dt);
    // Vitesse du ressort ramenée en pixels par image à 60 i/s, lissée.
    final perFrame = c.velocity / 60;
    _velocity = Offset.lerp(_velocity, f.motion ? perFrame : Offset.zero, 0.25)!;
  }

  @override
  void writeUniforms(UniformWriter w, FrameContext f) {
    writeHeader(w, f);
    w.offset(_center?.position ?? f.size.center(Offset.zero));
    w.offset(_velocity);
    w.float(_press.value.clamp(0.0, 1.0));
  }

  @override
  void paintFallback(Canvas canvas, FrameContext f) {
    paintAetherFallback(canvas, f.size, f.dark);
    final r = f.size.shortestSide * 0.22;
    final center = _center?.position ?? f.size.center(Offset.zero);
    paintMatterFallback(canvas, Rect.fromCircle(center: center, radius: r), f.dark, radius: r * 0.7);
  }
}
