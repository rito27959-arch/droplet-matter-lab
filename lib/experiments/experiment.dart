import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/frame_monitor.dart';
import '../core/lab_settings.dart';
import '../core/quality.dart';
import '../interactions/pointer_field.dart';
import '../lighting/light_follower.dart';
import '../rendering/shader_canvas.dart';
import '../rendering/shader_library.dart';
import '../rendering/uniforms.dart';
import '../ui/lab_theme.dart';

/// Ce qu'une expérience reçoit à chaque image.
class FrameContext {
  FrameContext({
    required this.time,
    required this.dt,
    required this.size,
    required this.pointer,
    required this.light,
    required this.dark,
    required this.quality,
    required this.motion,
  });

  final double time;
  final double dt;
  final Size size;
  final PointerState pointer;

  /// Position de la lumière, qui suit le pointeur avec un ressort lent.
  final Offset light;
  final bool dark;
  final MatterQuality quality;

  /// false quand l'utilisateur a demandé de réduire les animations.
  final bool motion;
}

/// La logique d'une expérience : ses uniformes, son repli, ses réglages.
abstract class ExperimentLogic {
  int get number;
  String get title;
  String get summary;
  String get shaderAsset;
  bool get usesScene => false;

  /// Avance l'état interne (ressorts, cycle).
  void tick(FrameContext f) {}

  /// Renseigne les uniformes, en-tête compris, dans l'ordre du shader.
  void writeUniforms(UniformWriter w, FrameContext f);

  /// Rendu LOW et rendu de secours si le shader est indisponible.
  void paintFallback(Canvas canvas, FrameContext f) {
    final c = LabColors.of(f.dark);
    canvas.drawRect(
      Offset.zero & f.size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, f.size.height),
          [c.background, Color.lerp(c.background, c.ink, 0.10)!],
        ),
    );
  }

  /// Widgets posés au-dessus de la matière (texte de la signature, etc.).
  Widget? foreground(BuildContext context, FrameContext f) => null;

  /// Réglages propres à l'expérience. `refresh` reconstruit le panneau.
  List<Widget> controls(BuildContext context, VoidCallback refresh, bool dark) => const [];

  /// Écrit l'en-tête commun.
  void writeHeader(UniformWriter w, FrameContext f) => w.header(
        size: f.size,
        time: f.time,
        quality: f.quality,
        dark: f.dark,
        pointer: f.light,
        motion: f.motion,
      );
}

/// Affiche une expérience : canevas plein écran, en-tête, panneau de réglages,
/// mesure des images, baisse de qualité automatique.
class ExperimentView extends StatefulWidget {
  const ExperimentView({super.key, required this.logic, required this.settings, required this.monitor, this.capture = false});

  final ExperimentLogic logic;
  final LabSettings settings;
  final FrameMonitor monitor;

  /// Mode capture : aucun réglage ouvert, temps figé si demandé.
  final bool capture;

  @override
  State<ExperimentView> createState() => _ExperimentViewState();
}

class _ExperimentViewState extends State<ExperimentView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  final _pointer = PointerState();
  LightFollower? _light;
  ui.FragmentShader? _shader;
  Duration _last = Duration.zero;
  double _elapsed = 0;
  FrameContext? _frame;
  bool _panelOpen = false;
  bool _motion = true;
  double _overBudgetFor = 0;
  String? _notice;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettings);
    _prepareShader();
    _ticker = createTicker(_onTick)..start();
  }

  void _onSettings() => setState(() {});

  Future<void> _prepareShader() async {
    final program = await ShaderLibrary.instance.load(widget.logic.shaderAsset);
    if (!mounted) return;
    setState(() => _shader = program?.fragmentShader());
  }

  void _onTick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    _elapsed += dt;
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final light = _light ??= LightFollower(Offset(size.width * 0.78, size.height * 0.16));
    if (_pointer.hasPosition) light.follow(_pointer.position);
    light.step(dt);
    if (!_pointer.pressed) _pointer.velocity = _pointer.velocity * 0.86;

    final time = widget.settings.frozenTime ?? _elapsed;
    final f = FrameContext(
      time: time,
      dt: widget.settings.frozenTime != null ? 0 : dt,
      size: size,
      pointer: _pointer,
      light: light.position,
      dark: widget.settings.dark,
      quality: widget.settings.quality,
      motion: _motion,
    );
    widget.logic.tick(f);
    _frame = f;
    _adapt(dt);
    _repaint.value++;
  }

  // Baisse d'un cran si plus d'un quart des images ratent leur budget pendant 2 s.
  void _adapt(double dt) {
    final s = widget.settings;
    if (!s.adaptiveQuality || widget.capture || s.quality == MatterQuality.low) return;
    if (widget.monitor.missRatio > 0.25) {
      _overBudgetFor += dt;
      if (_overBudgetFor > 2) {
        _overBudgetFor = 0;
        final from = s.quality;
        s.setQuality(from.lower);
        widget.monitor.reset();
        _notice = 'Qualité abaissée : ${from.label} → ${s.quality.label}';
      }
    } else {
      _overBudgetFor = 0;
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    _motion = !MediaQuery.disableAnimationsOf(context);
    final c = LabColors.of(s.dark);
    final useShader = s.quality.usesShader && _shader != null;
    final failed = ShaderLibrary.instance.failureOf(widget.logic.shaderAsset) != null;
    final scene = ShaderLibrary.instance.scene;
    final ready = !widget.logic.usesScene || scene != null;

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PointerField(
            state: _pointer,
            child: CustomPaint(
              painter: useShader && ready
                  ? ShaderPainter(
                      shader: _shader!,
                      image: widget.logic.usesScene ? scene : null,
                      repaint: _repaint,
                      setUniforms: (w, size) {
                        final f = _frame;
                        if (f == null) return;
                        widget.logic.writeUniforms(w, f);
                      },
                    )
                  : _FallbackPainter(logic: widget.logic, frame: () => _frame, repaint: _repaint),
              child: const SizedBox.expand(),
            ),
          ),
          if (_frame != null)
            IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: _repaint,
                builder: (context, _, __) => widget.logic.foreground(context, _frame!) ?? const SizedBox.shrink(),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _Header(
                logic: widget.logic,
                colors: c,
                quality: s.quality,
                fallbackReason: !s.quality.usesShader
                    ? 'Rendu LOW, sans shader'
                    : failed
                        ? 'Shader indisponible : rendu de repli'
                        : null,
                notice: _notice,
                capture: widget.capture,
              ),
            ),
          ),
          if (!widget.capture)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _Panel(
                    open: _panelOpen,
                    colors: c,
                    onToggle: () => setState(() => _panelOpen = !_panelOpen),
                    settings: s,
                    monitor: widget.monitor,
                    children: widget.logic.controls(context, () => setState(() {}), s.dark),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FallbackPainter extends CustomPainter {
  _FallbackPainter({required this.logic, required this.frame, super.repaint});

  final ExperimentLogic logic;
  final FrameContext? Function() frame;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame();
    if (f == null) return;
    logic.paintFallback(canvas, f);
  }

  @override
  bool shouldRepaint(covariant _FallbackPainter oldDelegate) => false;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.logic,
    required this.colors,
    required this.quality,
    required this.fallbackReason,
    required this.notice,
    required this.capture,
  });

  final ExperimentLogic logic;
  final LabColors colors;
  final MatterQuality quality;
  final String? fallbackReason;
  final String? notice;
  final bool capture;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (canPop && !capture)
              IconButton(
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: colors.ink),
              ),
            Text('Expérience ${logic.number.toString().padLeft(2, '0')}', style: LabType.data(colors.muted)),
            const Spacer(),
            Text(quality.label, style: LabType.data(colors.muted)),
          ],
        ),
        const SizedBox(height: 6),
        Text(logic.title, style: LabType.display(colors.ink, size: 30, flair: 70)),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(logic.summary, style: LabType.body(colors.muted, size: 14)),
        ),
        if (fallbackReason != null || notice != null) ...[
          const SizedBox(height: 8),
          Text(fallbackReason ?? notice!, style: LabType.data(colors.muted, size: 11)),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.open,
    required this.colors,
    required this.onToggle,
    required this.settings,
    required this.monitor,
    required this.children,
  });

  final bool open;
  final LabColors colors;
  final VoidCallback onToggle;
  final LabSettings settings;
  final FrameMonitor monitor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border.all(color: colors.hairline),
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (settings.showFrameStats)
                    ListenableBuilder(
                      listenable: monitor,
                      builder: (context, _) => Text(
                        '${monitor.averageMs.toStringAsFixed(1)} ms · ${monitor.estimatedFps.toStringAsFixed(0)} i/s · '
                        '${(monitor.missRatio * 100).toStringAsFixed(0)} % hors budget',
                        style: LabType.data(colors.muted, size: 11),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: onToggle,
                    child: Text(open ? 'Fermer' : 'Réglages', style: LabType.label(colors.ink)),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: const Cubic(0.1, 0.9, 0.2, 1),
                child: open
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _QualityPicker(settings: settings, colors: colors),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('Thème sombre', style: LabType.label(colors.ink)),
                            value: settings.dark,
                            onChanged: settings.setDark,
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('Qualité automatique', style: LabType.label(colors.ink)),
                            value: settings.adaptiveQuality,
                            onChanged: settings.setAdaptive,
                          ),
                          ...children,
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityPicker extends StatelessWidget {
  const _QualityPicker({required this.settings, required this.colors});

  final LabSettings settings;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 8),
      child: SegmentedButton<MatterQuality>(
        showSelectedIcon: false,
        segments: [
          for (final q in MatterQuality.values)
            ButtonSegment(value: q, label: Text(q.label, style: LabType.data(colors.ink, size: 10))),
        ],
        selected: {settings.quality},
        onSelectionChanged: (v) => settings.setQuality(v.first),
      ),
    );
  }
}

/// Curseur de réglage étiqueté, valeur affichée en Martian Mono.
class LabSlider extends StatelessWidget {
  const LabSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.dark,
    this.unit = '',
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool dark;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = LabColors.of(dark);
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label, style: LabType.label(c.ink))),
        Expanded(child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged)),
        SizedBox(
          width: 56,
          child: Text('${value.toStringAsFixed(value < 2 ? 2 : 0)}$unit', textAlign: TextAlign.right, style: LabType.data(c.muted)),
        ),
      ],
    );
  }
}
