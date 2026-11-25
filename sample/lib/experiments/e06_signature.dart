import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:droplet_glass/droplet_glass.dart';
import '../ui/lab_theme.dart';
import 'common_logic.dart';
import 'experiment.dart';

/// Expérience 06 — la signature : Light, Geometry, Matter et Motion ensemble.
///
/// Le nom « Droplet » est composé en Commissioner ; son axe Flair respire au
/// rythme de la goutte : la typographie fait partie de la matière.
class Signature extends ExperimentLogic with MorphLogic {
  @override
  int get number => 6;
  @override
  String get title => 'Signature';
  @override
  String get summary =>
      'Une goutte qui se transforme lentement dans l’atmosphère, et projette sous elle une caustique spectrale à peine visible.';
  @override
  String get shaderAsset => ShaderLibrary.signature;
  @override
  final MorphCycle morph = const MorphCycle(secondsPerShape: 5.5);

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
    final r = f.size.shortestSide * 0.2;
    paintMatterFallback(canvas, Rect.fromCircle(center: Offset(f.size.width / 2, f.size.height * 0.40), radius: r), f.dark);
  }

  @override
  Widget foreground(BuildContext context, FrameContext f) {
    final c = LabColors.of(f.dark);
    // Le Flair passe de 30 à 90 et revient, sur le rythme du cycle des formes.
    final breath = f.motion ? (0.5 - 0.5 * math.cos(cycle * math.pi * 2)) : 0.6;
    final flair = 30 + 60 * breath;
    return Align(
      alignment: const Alignment(0, 0.42),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Droplet', style: LabType.display(c.ink, size: 64, flair: flair)),
          const SizedBox(height: 10),
          Text('Prismatic Aether', style: LabType.data(c.muted, size: 12)),
        ],
      ),
    );
  }
}
