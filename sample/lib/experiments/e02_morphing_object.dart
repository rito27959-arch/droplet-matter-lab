import 'package:flutter/material.dart';

import 'package:droplet_glass/droplet_glass.dart';
import 'common_logic.dart';
import 'experiment.dart';

/// Expérience 02 — une forme mate qui passe d'un état à l'autre.
class MorphingObject extends ExperimentLogic with MorphLogic {
  @override
  int get number => 2;
  @override
  String get title => 'Objet en métamorphose';
  @override
  String get summary =>
      'Sphère, pavé, goutte, grappe. Chaque forme est tenue, puis glisse vers la suivante par interpolation de distances signées. Le relief est calculé, sans 3D.';
  @override
  String get shaderAsset => ShaderLibrary.morphingObject;
  @override
  final MorphCycle morph = const MorphCycle(secondsPerShape: 3.2);

  @override
  void tick(FrameContext f) => advanceMorph(f);

  @override
  void writeUniforms(UniformWriter w, FrameContext f) {
    writeHeader(w, f);
    w.float(cycle);
  }

  @override
  void paintFallback(Canvas canvas, FrameContext f) {
    paintAetherFallback(canvas, f.size, f.dark);
    final r = f.size.shortestSide * 0.24;
    paintMatterFallback(canvas, Rect.fromCircle(center: Offset(f.size.width / 2, f.size.height * 0.46), radius: r), f.dark);
  }

  @override
  List<Widget> controls(BuildContext context, VoidCallback refresh, bool dark) => [shapeControl(context, refresh, dark)];
}
