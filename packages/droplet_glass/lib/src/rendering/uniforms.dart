import 'dart:ui' as ui;

import 'package:droplet_core/droplet_core.dart';

/// Écrit les uniformes d'un shader dans l'ordre de leur déclaration.
///
/// Flutter renseigne les uniformes flottants par index : un `vec2` occupe deux
/// index. Cet écrivain tient le compte, pour qu'aucun shader ne dépende d'index
/// écrits à la main.
class UniformWriter {
  UniformWriter(this.shader);

  final ui.FragmentShader shader;
  int _index = 0;

  int get count => _index;

  void float(double value) => shader.setFloat(_index++, value);

  void vec2(double x, double y) {
    float(x);
    float(y);
  }

  void offset(ui.Offset o) => vec2(o.dx, o.dy);

  void size(ui.Size s) => vec2(s.width, s.height);

  /// Les huit flottants de `shaders/lib/header.glsl`, communs à tous les shaders.
  void header({
    required ui.Size size,
    required double time,
    required MatterQuality quality,
    required bool dark,
    required ui.Offset pointer,
    required bool motion,
  }) {
    this.size(size);
    float(time);
    float(quality.uniform);
    float(dark ? 1 : 0);
    offset(pointer);
    float(motion ? 1 : 0);
  }
}

/// Nombre de flottants de l'en-tête commun ; vérifié par les tests.
const int headerFloatCount = 8;
