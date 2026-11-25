import 'package:flutter/material.dart';

import '../rendering/shader_library.dart';
import '../rendering/uniforms.dart';
import 'common_logic.dart';
import 'experiment.dart';

/// Expérience 03 — l'atmosphère Aether seule.
class AetherAtmosphere extends ExperimentLogic {
  @override
  int get number => 3;
  @override
  String get title => 'Atmosphère Aether';
  @override
  String get summary =>
      'Une lumière diffuse, trois nappes de brume à trois profondeurs. Déplacez le doigt : les nappes glissent à des vitesses différentes, la profondeur apparaît.';
  @override
  String get shaderAsset => ShaderLibrary.aetherAtmosphere;

  @override
  void writeUniforms(UniformWriter w, FrameContext f) => writeHeader(w, f);

  @override
  void paintFallback(Canvas canvas, FrameContext f) => paintAetherFallback(canvas, f.size, f.dark);
}
