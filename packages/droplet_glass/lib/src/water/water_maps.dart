import 'dart:math' as math;
import 'dart:ui' as ui;

import 'rain_simulation.dart';

/// Transforme l'état de [RainSimulation] en trois textures, à demi-résolution :
///
/// - `height` : hauteur d'eau, canal rouge (gouttes + condensation) ;
/// - `clear` : là où l'eau ou le doigt a essuyé la buée, canal rouge ;
/// - la condensation, gardée d'une image à l'autre (interne).
///
/// Tout est dessiné par le GPU avec `Picture.toImageSync` : aucune lecture de
/// pixels côté processeur.
class WaterMaps {
  WaterMaps({this.scale = 0.5});

  /// Résolution des cartes par rapport aux pixels logiques.
  final double scale;

  ui.Image? _micro;
  ui.Image? _clear;
  ui.Image? _height;
  int _w = 0;
  int _h = 0;

  ui.Image? get height => _height;
  ui.Image? get clear => _clear;
  int get width => _w;
  int get heightPx => _h;
  bool get ready => _height != null && _clear != null;

  static const _black = ui.Color(0xFF000000);
  static const _white = ui.Color(0xFFFFFFFF);

  /// Profil d'une goutte posée : bord raide, sommet arrondi, h(d) = (1 − d²)^0,55.
  static final List<double> _stops = [for (var i = 0; i <= 12; i++) i / 12];
  static List<ui.Color> _profile(double k) => [
        for (final d in _stops)
          () {
            final h = d >= 1 ? 0.0 : math.pow(1 - d * d, 0.55) * k;
            final v = (h.clamp(0.0, 1.0) * 255).round();
            return ui.Color.fromARGB(255, v, v, v);
          }(),
      ];

  void _dropSprite(ui.Canvas c, ui.Offset center, double rx, double ry, double k) {
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(1, ry / rx);
    c.drawCircle(
      ui.Offset.zero,
      rx,
      ui.Paint()
        ..blendMode = ui.BlendMode.lighten
        ..shader = ui.Gradient.radial(ui.Offset.zero, rx, _profile(k), _stops),
    );
    c.restore();
  }

  void _ensure(ui.Size size) {
    final w = math.max(1, (size.width * scale).ceil());
    final h = math.max(1, (size.height * scale).ceil());
    if (w == _w && h == _h && _micro != null) return;
    _w = w;
    _h = h;
    final blank = _blank();
    _micro?.dispose();
    _clear?.dispose();
    _micro = blank;
    _clear = blank.clone();
  }

  ui.Image _blank() {
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawColor(_black, ui.BlendMode.src);
    return rec.endRecording().toImageSync(_w, _h);
  }

  ui.Image _redraw(ui.Image previous, void Function(ui.Canvas c) paint) {
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.drawImage(previous, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.src);
    c.scale(scale);
    paint(c);
    final next = rec.endRecording().toImageSync(_w, _h);
    previous.dispose();
    return next;
  }

  /// Consomme les traits et la condensation en attente, puis redessine les cartes.
  void update(RainSimulation sim) {
    _ensure(sim.size);

    final wipes = List.of(sim.pendingWipes);
    final micro = List.of(sim.pendingMicro);
    sim.pendingWipes.clear();
    sim.pendingMicro.clear();

    // La buée revient par paliers : une carte 8 bits ne sait pas décroître
    // de moins d'un niveau par image.
    final fogStep = sim.pendingFogReturn >= 0.025 ? sim.pendingFogReturn : 0.0;
    if (fogStep > 0) sim.pendingFogReturn = 0;

    _clear = _redraw(_clear!, (c) {
      if (fogStep > 0) {
        c.drawRect(
          ui.Rect.fromLTWH(0, 0, sim.size.width, sim.size.height),
          ui.Paint()..color = _black.withValues(alpha: fogStep.clamp(0.0, 1.0)),
        );
      }
      final p = ui.Paint()
        ..color = _white
        ..strokeCap = ui.StrokeCap.round
        ..style = ui.PaintingStyle.stroke;
      for (final w in wipes) {
        p.strokeWidth = w.width * 0.95;
        c.drawLine(w.from, w.to + const ui.Offset(0, 0.01), p);
      }
    });

    _micro = _redraw(_micro!, (c) {
      for (final m in micro) {
        _dropSprite(c, m.center, m.radius, m.radius, m.height);
      }
      // L'eau qui passe absorbe la condensation : on la remet à zéro (noir).
      final p = ui.Paint()
        ..color = _black
        ..strokeCap = ui.StrokeCap.round
        ..style = ui.PaintingStyle.stroke;
      for (final w in wipes) {
        p.strokeWidth = w.width;
        c.drawLine(w.from, w.to + const ui.Offset(0, 0.01), p);
      }
    });

    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.drawImage(_micro!, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.src);
    c.scale(scale);
    for (final d in sim.drops) {
      final k = math.min(1.0, 0.45 + d.r / 22);
      // Une goutte qui glisse s'allonge.
      final st = math.min(d.vy * 0.004, 0.35);
      final rx = d.r * (1 - st * 0.4);
      final ry = d.r * (1 + st);
      _dropSprite(c, ui.Offset(d.x, d.y - ry * 0.1), rx, ry, k);
    }
    final next = rec.endRecording().toImageSync(_w, _h);
    _height?.dispose();
    _height = next;
  }

  void dispose() {
    _micro?.dispose();
    _clear?.dispose();
    _height?.dispose();
    _micro = _clear = _height = null;
  }
}
