import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Un arrière-plan prêt pour la matière : l'image nette et sa version floue.
///
/// La version floue sert de « remplissage » au verre dépoli et à la buée :
/// elle est calculée une seule fois, au lieu de multiplier les échantillons
/// dans le shader à chaque image.
class Backdrop {
  Backdrop(this.sharp, this.blurred);

  final ui.Image sharp;
  final ui.Image blurred;

  double get width => sharp.width.toDouble();
  double get height => sharp.height.toDouble();

  static Future<Backdrop> fromAsset(String asset, {double sigma = 22, AssetBundle? bundle}) async {
    final data = await (bundle ?? rootBundle).load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final sharp = (await codec.getNextFrame()).image;
    return Backdrop(sharp, blur(sharp, sigma));
  }

  /// Flou gaussien hors écran, à demi-résolution (le flou n'a pas besoin de détail).
  static ui.Image blur(ui.Image src, double sigma) {
    final w = (src.width / 2).round();
    final h = (src.height / 2).round();
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final dst = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    canvas.saveLayer(dst, ui.Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma / 2, sigmaY: sigma / 2, tileMode: ui.TileMode.clamp));
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    canvas.restore();
    return rec.endRecording().toImageSync(w, h);
  }
}
