import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'uniforms.dart';

/// Signature d'une fonction qui renseigne les uniformes d'un shader pour une image.
typedef UniformSetter = void Function(UniformWriter w, Size size);

/// Peint un shader sur toute sa surface. Repeint à chaque changement de `repaint`.
class ShaderPainter extends CustomPainter {
  ShaderPainter({required this.shader, required this.setUniforms, this.image, super.repaint});

  final ui.FragmentShader shader;
  final UniformSetter setUniforms;
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final w = UniformWriter(shader);
    setUniforms(w, size);
    if (image != null) shader.setImageSampler(0, image!);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) =>
      oldDelegate.shader != shader || oldDelegate.image != image;
}
