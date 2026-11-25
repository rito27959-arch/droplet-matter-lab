// COPIE de l'application Droplet (shared/eau/simulation_eau.dart) — seuls les imports changent.
// ============================================================================
// L'EAU SUR LA VITRE — la simulation et ses cartes.
// ----------------------------------------------------------------------------
// Repris tel quel de Droplet Matter Lab (packages/droplet_glass/lib/src/water)
// pour que l'app et le laboratoire aient la même eau. Deux ajouts pour l'app :
//   • [RainSimulation.essuye] : la part de la vitre essuyée au doigt (0..1),
//     sur une grille grossière tenue côté processeur — c'est elle qui décide
//     quand la vitre est assez propre pour disparaître ;
//   • les réglages acceptent une buée qui ne revient pas (`fogReturnSeconds`
//     très grand) : au retour dans l'app, ce qu'on essuie reste essuyé.
// Ce fichier ne dessine rien à l'écran : voir `vitre_embuee.dart`.
// ============================================================================

import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

/// Une goutte d'eau posée sur la vitre. Unités : pixels logiques, secondes.
class Drop {
  Drop(this.x, this.y, this.r);

  double x;
  double y;

  /// Rayon de la base de la goutte.
  double r;
  double vx = 0;
  double vy = 0;

  /// Temps restant pendant lequel la goutte reste accrochée (frottement statique).
  double stick = 0;

  /// Distance parcourue depuis la dernière goutte laissée en traînée.
  double trail = 0;
  bool dead = false;

  double get volume => r * r * r;
}

/// Un trait que la carte « essuyée » doit recevoir : l'eau ou le doigt est passé là.
class WipeStroke {
  const WipeStroke(this.from, this.to, this.width);

  final Offset from;
  final Offset to;
  final double width;
}

/// Une micro-gouttelette de condensation à ajouter.
class MicroDrop {
  const MicroDrop(this.center, this.radius, this.height);

  final Offset center;
  final double radius;
  final double height;
}

/// Réglages de la pluie.
class RainSettings {
  const RainSettings({
    this.dropsPerSecond = 9,
    this.minRadius = 3,
    this.maxRadius = 14,
    this.slideRadius = 8.5,
    this.gravity = 900,
    this.fogReturnSeconds = 9,
    this.condensationPerSecond = 60,
    this.fingerRadius = 23,
    this.maxDrops = 260,
  });

  /// Nouvelles gouttes par seconde (intensité de la pluie).
  final double dropsPerSecond;
  final double minRadius;
  final double maxRadius;

  /// Au-delà de ce rayon, le poids l'emporte sur l'adhérence : la goutte glisse.
  final double slideRadius;
  final double gravity;

  /// Temps pour que la buée recouvre une zone essuyée.
  final double fogReturnSeconds;
  final double condensationPerSecond;
  final double fingerRadius;
  final int maxDrops;

  RainSettings copyWith({double? dropsPerSecond, double? fogReturnSeconds}) => RainSettings(
        dropsPerSecond: dropsPerSecond ?? this.dropsPerSecond,
        minRadius: minRadius,
        maxRadius: maxRadius,
        slideRadius: slideRadius,
        gravity: gravity,
        fogReturnSeconds: fogReturnSeconds ?? this.fogReturnSeconds,
        condensationPerSecond: condensationPerSecond,
        fingerRadius: fingerRadius,
        maxDrops: maxDrops,
      );
}

/// Simulation de gouttes sur une vitre.
///
/// Physique simplifiée mais fidèle à ce qu'on voit sur une fenêtre :
/// - une petite goutte adhère ; une grosse glisse, par à-coups (frottement
///   statique puis dynamique) ;
/// - en glissant, elle laisse derrière elle des gouttelettes et perd du volume ;
/// - deux gouttes qui se touchent fusionnent en conservant le volume
///   (r = ∛(r₁³ + r₂³)) ;
/// - l'eau essuie la buée sur son passage et absorbe la condensation ;
/// - la buée revient lentement.
///
/// Ce fichier ne dessine rien : il produit des gouttes et des traits que
/// [WaterMaps] transforme en textures pour le shader `water_glass`.
class RainSimulation {
  RainSimulation({required Size size, this.settings = const RainSettings(), int seed = 7})
      : _size = size,
        _random = math.Random(seed);

  RainSettings settings;
  final math.Random _random;
  Size _size;
  double time = 0;

  final List<Drop> drops = [];

  /// Traits à reporter sur la carte essuyée (et à retirer de la condensation).
  final List<WipeStroke> pendingWipes = [];

  /// Condensation à ajouter.
  final List<MicroDrop> pendingMicro = [];

  /// Part de buée revenue depuis la dernière lecture (0 à 1), appliquée par paliers.
  double pendingFogReturn = 0;

  /// La grille grossière de ce que le doigt a essuyé (colonnes × lignes).
  static const int _gx = 12;
  static const int _gy = 24;
  final List<bool> _grille = List<bool>.filled(_gx * _gy, false);
  int _essuyees = 0;

  /// La part de la vitre essuyée au doigt, de 0 à 1.
  double get essuye => _essuyees / (_gx * _gy);

  void _marquer(Offset p, double rayon) {
    if (_size.isEmpty) return;
    final cw = _size.width / _gx;
    final ch = _size.height / _gy;
    final x0 = ((p.dx - rayon) / cw).floor().clamp(0, _gx - 1);
    final x1 = ((p.dx + rayon) / cw).floor().clamp(0, _gx - 1);
    final y0 = ((p.dy - rayon) / ch).floor().clamp(0, _gy - 1);
    final y1 = ((p.dy + rayon) / ch).floor().clamp(0, _gy - 1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * _gx + x;
        if (!_grille[i]) {
          _grille[i] = true;
          _essuyees++;
        }
      }
    }
  }

  double _spawnBudget = 0;
  double _microBudget = 0;
  double _fingerTravel = 0;

  Size get size => _size;

  void resize(Size size) => _size = size;

  double _rand() => _random.nextDouble();

  void spawn(double x, double y, double r) {
    drops.add(Drop(x, y, r));
  }

  /// Avance la simulation de `dt` secondes.
  void step(double dt) {
    if (dt <= 0 || _size.isEmpty) return;
    dt = math.min(dt, 0.05);
    time += dt;
    final s = settings;

    // Nouvelles gouttes : surtout des petites, quelques grosses.
    _spawnBudget += s.dropsPerSecond * dt;
    while (_spawnBudget >= 1) {
      _spawnBudget -= 1;
      final r = s.minRadius + math.pow(_rand(), 2.2) * (s.maxRadius - s.minRadius);
      spawn(_rand() * _size.width, _rand() * _size.height * 0.95, r.toDouble());
    }

    // Condensation : dense au début, puis entretenue.
    _microBudget += dt * (time < 2 ? 500 : s.condensationPerSecond);
    while (_microBudget >= 1) {
      _microBudget -= 1;
      pendingMicro.add(MicroDrop(
        Offset(_rand() * _size.width, _rand() * _size.height),
        0.8 + _rand() * 2.1,
        0.10 + _rand() * 0.12,
      ));
    }

    pendingFogReturn += dt / s.fogReturnSeconds;

    final born = <Drop>[];
    for (final d in drops) {
      final ox = d.x;
      final oy = d.y;
      if (d.r > s.slideRadius) {
        if (d.stick > 0) {
          d.stick -= dt;
          d.vy *= math.pow(0.02, dt);
        } else {
          final weight = math.min(1.0, (d.r - s.slideRadius) / 6);
          d.vy = math.min(d.vy + s.gravity * weight * dt, 60 + d.r * 22);
          // Une impureté de la vitre arrête la goutte un instant.
          if (_rand() < dt * 1.6) d.stick = 0.05 + _rand() * 0.35;
        }
        d.vx = (d.vx + (_rand() - 0.5) * dt * 120) * math.pow(0.05, dt);
      } else {
        d.vy *= math.pow(0.01, dt);
        d.vx *= 0.5;
      }
      d.x += d.vx * dt;
      d.y += d.vy * dt;

      if (d.vy > 4) {
        d.trail += d.vy * dt;
        if (d.trail > d.r * (1.1 + _rand() * 1.4)) {
          d.trail = 0;
          final tr = d.r * (0.22 + _rand() * 0.16);
          born.add(Drop(d.x + (_rand() - 0.5) * d.r * 0.3, d.y - d.r * 1.05, tr));
          d.r = math.pow(math.max(d.volume - tr * tr * tr, 1), 1 / 3).toDouble();
        }
      }
      pendingWipes.add(WipeStroke(Offset(ox, oy), Offset(d.x, d.y), d.r * 2.9));
    }
    drops.addAll(born);
    _merge();
    drops.removeWhere((d) => d.dead || d.y - d.r > _size.height || d.r < 0.8);
    if (drops.length > s.maxDrops) drops.removeRange(0, drops.length - s.maxDrops);
  }

  // Fusion : balayage trié par hauteur, pour ne comparer que les voisines.
  void _merge() {
    drops.sort((a, b) => a.y.compareTo(b.y));
    for (var i = 0; i < drops.length; i++) {
      final a = drops[i];
      if (a.dead) continue;
      for (var j = i + 1; j < drops.length; j++) {
        final b = drops[j];
        if (b.dead) continue;
        if (b.y - a.y > a.r + b.r) break;
        final dx = a.x - b.x;
        final dy = a.y - b.y;
        final reach = (a.r + b.r) * 0.75;
        if (dx * dx + dy * dy < reach * reach) {
          final va = a.volume;
          final vb = b.volume;
          final big = va >= vb ? a : b;
          final small = identical(big, a) ? b : a;
          big
            ..x = (a.x * va + b.x * vb) / (va + vb)
            ..y = math.max(a.y, b.y)
            ..r = math.pow(va + vb, 1 / 3).toDouble()
            ..vy = math.max(a.vy, b.vy)
            ..stick = 0;
          small.dead = true;
        }
      }
    }
  }

  /// Le doigt essuie la vitre de `from` à `to` : la buée part, l'eau est
  /// ramassée et repoussée en perles sur le bord du sillon.
  void wipe(Offset from, Offset to) {
    final fr = settings.fingerRadius;
    pendingWipes.add(WipeStroke(from, to, fr * 2));
    final seg = to - from;
    // La grille : un point tous les demi-rayons le long du trait.
    final pas = math.max(1, (seg.distance / (fr * 0.5)).ceil());
    for (var k = 0; k <= pas; k++) {
      _marquer(from + seg * (k / pas), fr * 0.8);
    }
    final len2 = math.max(1.0, seg.distanceSquared);
    var gathered = 0.0;
    for (final d in drops) {
      final t = (((d.x - from.dx) * seg.dx + (d.y - from.dy) * seg.dy) / len2).clamp(0.0, 1.0).toDouble();
      final p = from + seg * t;
      final dx = d.x - p.dx;
      final dy = d.y - p.dy;
      final reach = fr + d.r * 0.5;
      if (dx * dx + dy * dy < reach * reach) {
        gathered += d.volume;
        d.dead = true;
      }
    }
    drops.removeWhere((d) => d.dead);
    final len = seg.distance;
    _fingerTravel += len;
    if (len > 0 && _fingerTravel > 16) {
      _fingerTravel = 0;
      final n = Offset(-seg.dy / len, seg.dx / len);
      final side = _rand() < 0.5 ? -1.0 : 1.0;
      final base = 3 + _rand() * 4;
      final r = math.min(math.pow(gathered + base * base * base, 1 / 3).toDouble(), 13.0);
      final p = to + n * side * (fr + 4 + _rand() * 4);
      spawn(p.dx, p.dy, r);
    }
  }

  /// Volume total d'eau (utile aux tests : la fusion conserve le volume).
  double get totalVolume => drops.fold(0.0, (v, d) => v + d.volume);
}


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
