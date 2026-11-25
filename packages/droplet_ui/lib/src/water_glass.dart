import 'dart:ui' as ui;

import 'package:droplet_core/droplet_core.dart';
import 'package:droplet_glass/droplet_glass.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// De l'eau sur la vitre de l'écran.
///
/// Des gouttes tombent, glissent par à-coups, laissent des traînées,
/// fusionnent. La buée couvre le fond ; l'eau et le doigt l'essuient, puis
/// elle revient. Chaque goutte est une lentille d'eau (n ≈ 1,333) qui renverse
/// le fond, avec reflet, bord sombre et caustique.
///
/// Glissez le doigt pour essuyer la vitre.
class WaterGlass extends StatefulWidget {
  const WaterGlass({
    super.key,
    required this.backdrop,
    this.quality = MatterQuality.high,
    this.dark = false,
    this.fog = 1,
    this.rain = const RainSettings(),
    this.refraction = 300,
    this.dropHeight = 14,
    this.warmUpSeconds = 8,
    this.seed = 7,
    this.light,
    this.interactive = true,
  });

  final Backdrop backdrop;
  final MatterQuality quality;
  final bool dark;

  /// 0 : vitre sèche et nette ; 1 : buée complète.
  final double fog;
  final RainSettings rain;

  /// Distance apparente du fond derrière l'eau, en pixels : plus elle est
  /// grande, plus l'image dans la goutte est renversée et rapetissée.
  final double refraction;

  /// Hauteur d'une goutte en pixels : règle la pente, donc le bord sombre.
  final double dropHeight;

  /// Pluie simulée avant la première image, pour ne pas partir d'une vitre vide.
  final double warmUpSeconds;
  final int seed;

  /// Position de la lumière ; par défaut en haut à droite.
  final Offset? light;
  final bool interactive;

  @override
  State<WaterGlass> createState() => _WaterGlassState();
}

class _WaterGlassState extends State<WaterGlass> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  final _maps = WaterMaps();
  RainSimulation? _sim;
  ui.FragmentShader? _shader;
  Duration _last = Duration.zero;
  Offset? _finger;
  Size _size = Size.zero;
  bool _motion = true;

  @override
  void initState() {
    super.initState();
    ShaderLibrary.instance.load(ShaderLibrary.waterGlass).then((p) {
      if (mounted && p != null) setState(() => _shader = p.fragmentShader());
    });
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(WaterGlass old) {
    super.didUpdateWidget(old);
    _sim?.settings = widget.rain;
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    if (_size.isEmpty) return;
    final sim = _sim ??= _start(_size);
    sim.resize(_size);
    // Animations réduites : la vitre reste figée, seul le doigt agit.
    if (_motion) sim.step(dt);
    _maps.update(sim);
    _repaint.value++;
  }

  RainSimulation _start(Size size) {
    final sim = RainSimulation(size: size, settings: widget.rain, seed: widget.seed);
    const step = 1 / 30;
    for (var t = 0.0; t < widget.warmUpSeconds; t += step) {
      sim.step(step);
    }
    return sim;
  }

  void _wipe(Offset to) {
    final from = _finger ?? to;
    _finger = to;
    _sim?.wipe(from, to);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    _maps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _motion = !MediaQuery.disableAnimationsOf(context);
    final useShader = widget.quality.usesShader && _shader != null;
    final paint = LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      return CustomPaint(
        size: box.biggest,
        painter: useShader
            ? _WaterPainter(state: this, shader: _shader!, repaint: _repaint)
            : _WaterFallbackPainter(state: this, repaint: _repaint),
      );
    });
    if (!widget.interactive) return paint;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _finger = e.localPosition;
        _wipe(e.localPosition);
      },
      onPointerMove: (e) => _wipe(e.localPosition),
      onPointerUp: (_) => _finger = null,
      onPointerCancel: (_) => _finger = null,
      child: paint,
    );
  }
}

class _WaterPainter extends CustomPainter {
  _WaterPainter({required this.state, required this.shader, super.repaint});

  final _WaterGlassState state;
  final ui.FragmentShader shader;

  @override
  void paint(Canvas canvas, Size size) {
    final maps = state._maps;
    final sim = state._sim;
    final w = state.widget;
    if (!maps.ready || sim == null) {
      paintCover(canvas, size, w.backdrop.blurred);
      return;
    }
    final u = UniformWriter(shader);
    u.header(
      size: size,
      time: sim.time,
      quality: w.quality,
      dark: w.dark,
      pointer: w.light ?? Offset(size.width * 0.8, size.height * 0.1),
      motion: state._motion,
    );
    u.vec2(w.backdrop.width, w.backdrop.height);
    u.float(w.fog);
    u.float(w.refraction);
    u.float(w.dropHeight);
    u.vec2(maps.width.toDouble(), maps.heightPx.toDouble());
    shader
      ..setImageSampler(0, w.backdrop.sharp)
      ..setImageSampler(1, w.backdrop.blurred)
      ..setImageSampler(2, maps.height!)
      ..setImageSampler(3, maps.clear!);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _WaterPainter old) => old.shader != shader;
}

/// Rendu LOW et rendu de secours : fond flou, gouttes dessinées simplement.
class _WaterFallbackPainter extends CustomPainter {
  _WaterFallbackPainter({required this.state, super.repaint});

  final _WaterGlassState state;

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.widget;
    paintCover(canvas, size, w.fog > 0.5 ? w.backdrop.blurred : w.backdrop.sharp);
    final sim = state._sim;
    if (sim == null) return;
    final fill = Paint()..color = const Color(0x33FFFFFF);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x55000000);
    final glint = Paint()..color = const Color(0xCCFFFFFF);
    for (final d in sim.drops) {
      final c = Offset(d.x, d.y);
      canvas.drawCircle(c, d.r, fill);
      canvas.drawCircle(c, d.r, rim);
      canvas.drawCircle(c + Offset(d.r * 0.35, -d.r * 0.4), d.r * 0.18, glint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterFallbackPainter old) => false;
}

/// Peint une image en « cover » (comme le shader), centrée.
void paintCover(Canvas canvas, Size size, ui.Image image) {
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  final s = (size.width / iw) > (size.height / ih) ? size.width / iw : size.height / ih;
  final dst = Rect.fromCenter(center: size.center(Offset.zero), width: iw * s, height: ih * s);
  canvas.drawImageRect(image, Rect.fromLTWH(0, 0, iw, ih), dst, Paint()..filterQuality = FilterQuality.medium);
}
