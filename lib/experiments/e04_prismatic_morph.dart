import 'package:flutter/material.dart';

import '../geometry/morph_cycle.dart';
import '../rendering/shader_library.dart';
import '../rendering/uniforms.dart';
import 'common_logic.dart';
import 'experiment.dart';

/// Expérience 04 — la forme vivante, faite de Droplet Matter, sur un contenu réel.
class PrismaticMorph extends ExperimentLogic with MorphLogic {
  @override
  int get number => 4;
  @override
  String get title => 'Morph prismatique';
  @override
  String get summary =>
      'La géométrie de l’expérience 02 devient matière. Quand la forme change, ses bords changent, et la lumière qu’ils dévient change avec eux.';
  @override
  String get shaderAsset => ShaderLibrary.prismaticMorph;
  @override
  bool get usesScene => true;
  @override
  final MorphCycle morph = const MorphCycle(secondsPerShape: 3.6);

  double refraction = 30;
  double dispersion = 0.38;

  @override
  void tick(FrameContext f) => advanceMorph(f);

  @override
  void writeUniforms(UniformWriter w, FrameContext f) {
    final image = ShaderLibrary.instance.scene!;
    writeHeader(w, f);
    w.vec2(image.width.toDouble(), image.height.toDouble());
    w.float(cycle);
    w.float(refraction);
    w.float(dispersion);
  }

  @override
  void paintFallback(Canvas canvas, FrameContext f) {
    paintSceneFallback(canvas, f.size);
    final r = f.size.shortestSide * 0.26;
    paintMatterFallback(canvas, Rect.fromCircle(center: Offset(f.size.width / 2, f.size.height * 0.42), radius: r), f.dark);
  }

  @override
  List<Widget> controls(BuildContext context, VoidCallback refresh, bool dark) => [
        shapeControl(context, refresh, dark),
        LabSlider(label: 'Réfraction', value: refraction, min: 0, max: 60, unit: ' px', dark: dark, onChanged: (v) {
          refraction = v;
          refresh();
        }),
        LabSlider(label: 'Dispersion', value: dispersion, min: 0, max: 0.6, dark: dark, onChanged: (v) {
          dispersion = v;
          refresh();
        }),
      ];
}
