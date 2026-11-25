import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:droplet_glass/droplet_glass.dart';
import '../ui/lab_theme.dart';
import '../core/lab_scene.dart';
import 'experiment.dart';

/// Paramètres de capture, lus dans l'adresse sur le web (voir main.dart).
class CaptureParams {
  static double? cycle;
}

/// Logique partagée par les expériences qui font varier la forme.
mixin MorphLogic on ExperimentLogic {
  MorphCycle get morph;
  double _cycle = 0;
  double _manual = 0;

  /// Position dans le cycle des formes : avance seule, sauf animations réduites.
  double get cycle => CaptureParams.cycle ?? _cycle;

  void advanceMorph(FrameContext f) {
    if (f.motion) {
      _cycle = morph.at(f.time) + _manual;
    } else {
      _cycle = _manual;
    }
  }

  void nextShape() => _manual = (_manual.floor() + 1).toDouble();

  Widget shapeControl(BuildContext context, VoidCallback refresh, bool dark) {
    final c = LabColors.of(dark);
    return Row(
      children: [
        Text('Forme : ${MorphCycle.shapeName(cycle)}', style: LabType.label(c.ink)),
        const Spacer(),
        TextButton(
          onPressed: () {
            nextShape();
            refresh();
          },
          child: Text('Forme suivante', style: LabType.label(c.ink)),
        ),
      ],
    );
  }
}

/// Fond de repli : l'image de contenu en mode « couvrir ».
void paintSceneFallback(Canvas canvas, Size size) {
  final image = LabScene.image;
  if (image == null) return;
  paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.cover);
}

/// Fond de repli Aether : dégradé et halo, sans bruit.
void paintAetherFallback(Canvas canvas, Size size, bool dark) {
  final top = dark ? const Color(0xFF0C141B) : const Color(0xFFDDE3E9);
  final bottom = dark ? const Color(0xFF04060A) : const Color(0xFFC7CFD7);
  canvas.drawRect(
    Offset.zero & size,
    Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [top, bottom]),
  );
  final glow = Offset(size.width * 0.2, -size.height * 0.05);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.radial(glow, size.longestSide * 0.7, [
        (dark ? const Color(0xFF8FC2E6) : Colors.white).withValues(alpha: dark ? 0.22 : 0.55),
        Colors.transparent,
      ]),
  );
}

/// Goutte de repli : un disque translucide avec un liseré, sans réfraction.
void paintMatterFallback(Canvas canvas, Rect bounds, bool dark, {double radius = 999}) {
  final rrect = RRect.fromRectAndRadius(bounds, Radius.circular(radius.clamp(0, bounds.shortestSide / 2)));
  canvas.drawRRect(
    rrect.shift(const Offset(0, 12)),
    Paint()
      ..color = Colors.black.withValues(alpha: dark ? 0.35 : 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
  canvas.drawRRect(rrect, Paint()..color = (dark ? const Color(0xFF1A232B) : Colors.white).withValues(alpha: 0.72));
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: dark ? 0.18 : 0.10),
  );
}
