import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:droplet_core/droplet_core.dart';
import 'package:droplet_glass/droplet_glass.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'water_glass.dart' show paintCover;

/// Un onglet de [LiquidTabBar].
class LiquidTab {
  const LiquidTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Une barre d'onglets en verre liquide, posée sur un contenu qui défile.
///
/// Inspirée du principe décrit publiquement par Apple (WWDC 2025) : le verre
/// courbe la lumière au lieu de la diffuser, il reste réservé à la couche de
/// navigation, et la sélection est une lentille qui se déplace. Ici :
/// - la barre est un verre dépoli à profil physique (réfraction de Snell,
///   dispersion, liseré spéculaire) ;
/// - la lentille de sélection est un verre net, plus épais, qui grossit ;
/// - on peut la faire glisser d'un onglet à l'autre ; en appui elle se
///   soulève, s'étire dans le sens du geste et fusionne avec la barre.
///
/// Limite : le contenu réfracté est une image ([Backdrop]) que le widget fait
/// défiler lui-même ; ce n'est pas encore l'arbre de widgets réel.
class LiquidTabBar extends StatefulWidget {
  const LiquidTabBar({
    super.key,
    required this.backdrop,
    required this.tabs,
    this.initialIndex = 0,
    this.onChanged,
    this.quality = MatterQuality.high,
    this.dark = false,
    this.accent = const Color(0xFF2F7CF6),
    this.bottomInset = 24,
  });

  final Backdrop backdrop;
  final List<LiquidTab> tabs;
  final int initialIndex;
  final ValueChanged<int>? onChanged;
  final MatterQuality quality;
  final bool dark;
  final Color accent;
  final double bottomInset;

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  ui.FragmentShader? _shader;
  Duration _last = Duration.zero;
  double _time = 0;
  Size _size = Size.zero;
  bool _motion = true;

  late int _index = widget.initialIndex;
  Spring1D? _lensX;
  final _press = Spring1D(stiffness: MotionTokens.springPress.stiffness, dampingRatio: MotionTokens.springPress.damping);

  // Défilement du contenu, avec inertie.
  double _scroll = 0;
  double _scrollVelocity = 0;
  bool _draggingLens = false;
  bool _draggingContent = false;
  double? _lastY;

  static const _barHeight = 64.0;
  static const _lensHeight = 52.0;

  @override
  void initState() {
    super.initState();
    ShaderLibrary.instance.load(ShaderLibrary.liquidBar).then((p) {
      if (mounted && p != null) setState(() => _shader = p.fragmentShader());
    });
    _ticker = createTicker(_tick)..start();
  }

  Rect _barRect(Size size) {
    final w = math.min(size.width - 32, 420.0);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height - widget.bottomInset - _barHeight / 2),
      width: w,
      height: _barHeight,
    );
  }

  double _tabWidth(Rect bar) => (bar.width - 12) / widget.tabs.length;

  double _tabCenter(Rect bar, int i) => bar.left + 6 + _tabWidth(bar) * (i + 0.5);

  int _tabAt(Rect bar, double x) =>
      ((x - bar.left - 6) / _tabWidth(bar)).floor().clamp(0, widget.tabs.length - 1);

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    _time += dt;
    if (_size.isEmpty) return;
    final bar = _barRect(_size);
    final lens = _lensX ??= Spring1D(
      value: _tabCenter(bar, _index),
      stiffness: MotionTokens.springFollow.stiffness,
      dampingRatio: MotionTokens.springFollow.damping,
    );
    if (!_draggingLens) lens.target = _tabCenter(bar, _index);
    lens.step(dt);
    _press.target = _draggingLens ? 1 : 0;
    _press.step(dt);
    if (!_draggingContent) {
      _scroll += _scrollVelocity * dt;
      _scrollVelocity *= math.pow(0.04, dt).toDouble();
      // Défilement lent par défaut, pour voir la réfraction vivre.
      if (_motion && _scrollVelocity.abs() < 4) _scroll += 14 * dt;
    }
    _repaint.value++;
  }

  void _down(PointerDownEvent e) {
    final bar = _barRect(_size);
    if (bar.inflate(8).contains(e.localPosition)) {
      _draggingLens = true;
      _lensX?.target = e.localPosition.dx.clamp(bar.left + 30, bar.right - 30);
    } else {
      _draggingContent = true;
      _lastY = e.localPosition.dy;
      _scrollVelocity = 0;
    }
  }

  void _move(PointerMoveEvent e) {
    final bar = _barRect(_size);
    if (_draggingLens) {
      _lensX?.target = e.localPosition.dx.clamp(bar.left + 30, bar.right - 30);
    } else if (_draggingContent && _lastY != null) {
      final dy = e.localPosition.dy - _lastY!;
      _lastY = e.localPosition.dy;
      _scroll -= dy;
      final dtSeconds = 1 / 60;
      _scrollVelocity = ui.lerpDouble(_scrollVelocity, -dy / dtSeconds, 0.4)!;
    }
  }

  void _up(PointerEvent e) {
    if (_draggingLens) {
      final bar = _barRect(_size);
      final i = _tabAt(bar, _lensX?.target ?? e.localPosition.dx);
      if (i != _index) {
        setState(() => _index = i);
        widget.onChanged?.call(i);
      }
    }
    _draggingLens = false;
    _draggingContent = false;
    _lastY = null;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _motion = !MediaQuery.disableAnimationsOf(context);
    final useShader = widget.quality.usesShader && _shader != null;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: LayoutBuilder(builder: (context, box) {
        _size = box.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: useShader
                  ? _BarPainter(state: this, shader: _shader!, repaint: _repaint)
                  : _BarFallbackPainter(state: this, repaint: _repaint),
            ),
            _Icons(state: this),
          ],
        );
      }),
    );
  }
}

class _Icons extends StatelessWidget {
  const _Icons({required this.state});

  final _LiquidTabBarState state;

  @override
  Widget build(BuildContext context) {
    final w = state.widget;
    final ink = w.dark ? const Color(0xFFE9EEF4) : const Color(0xFF1B2230);
    return ValueListenableBuilder<int>(
      valueListenable: state._repaint,
      builder: (context, _, __) {
        if (state._size.isEmpty) return const SizedBox.shrink();
        final bar = state._barRect(state._size);
        final lensX = state._lensX?.value ?? state._tabCenter(bar, state._index);
        return Stack(children: [
          for (var i = 0; i < w.tabs.length; i++)
            Positioned(
              left: state._tabCenter(bar, i) - state._tabWidth(bar) / 2,
              top: bar.top,
              width: state._tabWidth(bar),
              height: bar.height,
              child: Semantics(
                button: true,
                selected: i == state._index,
                label: w.tabs[i].label,
                child: Builder(builder: (context) {
                  // L'icône sous la lentille prend la couleur d'accent, en proportion.
                  final near = (1 - ((lensX - state._tabCenter(bar, i)).abs() / state._tabWidth(bar))).clamp(0.0, 1.0);
                  final color = Color.lerp(ink.withValues(alpha: 0.72), w.accent, near)!;
                  final scale = 1 + 0.12 * state._press.value * near;
                  return Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(w.tabs[i].icon, size: 22, color: color),
                        const SizedBox(height: 2),
                        Text(
                          w.tabs[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontFamily: DropletFonts.text,
                            package: DropletFonts.package,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ]);
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.state, required this.shader, super.repaint});

  final _LiquidTabBarState state;
  final ui.FragmentShader shader;

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.widget;
    final bar = state._barRect(size);
    final lensX = state._lensX?.value ?? state._tabCenter(bar, state._index);
    final press = state._press.value;
    final stretch = (state._lensX?.target ?? lensX) - lensX;
    final u = UniformWriter(shader);
    u.header(
      size: size,
      time: state._time,
      quality: w.quality,
      dark: w.dark,
      pointer: Offset(size.width * 0.8, size.height * 0.35),
      motion: state._motion,
    );
    u.vec2(w.backdrop.width, w.backdrop.height);
    u.float(state._scroll);
    u.offset(bar.center);
    u.vec2(bar.width, bar.height);
    u.vec2(lensX, bar.center.dy - 6 * press);
    u.vec2(state._tabWidth(bar) - 8, _LiquidTabBarState._lensHeight);
    u.float(stretch.clamp(-40.0, 40.0));
    u.float(press);
    shader
      ..setImageSampler(0, w.backdrop.sharp)
      ..setImageSampler(1, w.backdrop.blurred);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.shader != shader;
}

class _BarFallbackPainter extends CustomPainter {
  _BarFallbackPainter({required this.state, super.repaint});

  final _LiquidTabBarState state;

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.widget;
    paintCover(canvas, size, w.backdrop.sharp);
    final bar = state._barRect(size);
    final r = RRect.fromRectAndRadius(bar, Radius.circular(bar.height / 2));
    canvas.drawRRect(r, Paint()..color = (w.dark ? const Color(0xCC14181F) : const Color(0xCCF4F6F9)));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x33FFFFFF),
    );
    final lensX = state._lensX?.value ?? state._tabCenter(bar, state._index);
    final lens = Rect.fromCenter(center: Offset(lensX, bar.center.dy), width: state._tabWidth(bar) - 8, height: 52);
    canvas.drawRRect(RRect.fromRectAndRadius(lens, const Radius.circular(26)), Paint()..color = w.accent.withValues(alpha: 0.14));
  }

  @override
  bool shouldRepaint(covariant _BarFallbackPainter old) => false;
}
