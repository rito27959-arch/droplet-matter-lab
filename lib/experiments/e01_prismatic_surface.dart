import 'package:flutter/material.dart';

import '../core/quality.dart';
import '../materials/droplet_matter.dart';
import '../motion/motion_tokens.dart';
import '../motion/spring.dart';
import '../rendering/shader_library.dart';
import '../rendering/uniforms.dart';
import 'common_logic.dart';
import 'experiment.dart';

/// Expérience 01 — un panneau de Droplet Matter sur un contenu réel.
/// Glissez le panneau : la réfraction des bords et le liseré spectral suivent.
class PrismaticSurface extends ExperimentLogic {
  @override
  int get number => 1;
  @override
  String get title => 'Surface prismatique';
  @override
  String get summary =>
      'Un panneau presque mat. La lumière ne se courbe qu’au bord et se sépare en un liseré spectral de deux pixels. Glissez-le sur la liste.';
  @override
  String get shaderAsset => ShaderLibrary.prismaticSurface;
  @override
  bool get usesScene => true;

  MatterParams? _custom;
  MatterQuality? _lastQuality;
  MatterParams _params = MatterParams.surfaceFor(MatterQuality.high);
  Spring2D? _center;

  @override
  void tick(FrameContext f) {
    if (_lastQuality != f.quality) {
      _lastQuality = f.quality;
      _params = _custom ?? MatterParams.surfaceFor(f.quality);
    }
    final home = Offset(f.size.width / 2, f.size.height * 0.56);
    final c = _center ??= Spring2D(
      position: home,
      stiffness: MotionTokens.springFollow.stiffness,
      dampingRatio: MotionTokens.springFollow.damping,
    );
    c.target = f.pointer.pressed ? f.pointer.position : c.target;
    c.step(f.dt);
  }

  Size _panelSize(Size s) => Size((s.width - 48).clamp(200, 420).toDouble(), 220);

  @override
  void writeUniforms(UniformWriter w, FrameContext f) {
    final image = ShaderLibrary.instance.scene!;
    writeHeader(w, f);
    w.vec2(image.width.toDouble(), image.height.toDouble());
    w.float(_params.refraction);
    w.float(_params.dispersion);
    w.float(_params.frost);
    w.float(_params.tint);
    w.offset(_center?.position ?? f.size.center(Offset.zero));
    w.size(_panelSize(f.size));
  }

  @override
  void paintFallback(Canvas canvas, FrameContext f) {
    paintSceneFallback(canvas, f.size);
    final rect = Rect.fromCenter(
      center: _center?.position ?? f.size.center(Offset.zero),
      width: _panelSize(f.size).width,
      height: _panelSize(f.size).height,
    );
    paintMatterFallback(canvas, rect, f.dark, radius: 36);
  }

  @override
  List<Widget> controls(BuildContext context, VoidCallback refresh, bool dark) {
    void set(MatterParams p) {
      _custom = p;
      _params = p;
      refresh();
    }

    return [
      LabSlider(label: 'Réfraction', value: _params.refraction, min: 0, max: 48, unit: ' px', dark: dark, onChanged: (v) => set(_params.copyWith(refraction: v))),
      LabSlider(label: 'Dispersion', value: _params.dispersion, min: 0, max: 0.6, dark: dark, onChanged: (v) => set(_params.copyWith(dispersion: v))),
      LabSlider(label: 'Dépoli', value: _params.frost, min: 0, max: 20, unit: ' px', dark: dark, onChanged: (v) => set(_params.copyWith(frost: v))),
      LabSlider(label: 'Opacité', value: _params.tint, min: 0, max: 1, dark: dark, onChanged: (v) => set(_params.copyWith(tint: v))),
    ];
  }
}
