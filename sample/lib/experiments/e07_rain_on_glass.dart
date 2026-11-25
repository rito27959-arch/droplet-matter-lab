import 'package:droplet_glass/droplet_glass.dart';
import 'package:droplet_ui/droplet_ui.dart';
import 'package:flutter/material.dart';

import '../core/lab_scene.dart';
import '../core/lab_settings.dart';
import 'experiment.dart';

/// Expérience 07 — de l'eau sur la vitre de l'écran.
class RainOnGlass extends ExperimentLogic {
  @override
  int get number => 7;
  @override
  String get title => 'Pluie sur verre';
  @override
  String get summary =>
      'Des gouttes glissent, s’arrêtent, repartent et fusionnent. Chacune renverse l’image comme une vraie lentille d’eau. Essuyez la buée du doigt : elle revient.';
  @override
  String get shaderAsset => ShaderLibrary.waterGlass;

  double _fog = 1;
  double _rain = 9;
  double _refraction = 300;
  Key _key = UniqueKey();

  @override
  void writeUniforms(UniformWriter w, FrameContext f) {}

  @override
  Widget? body(BuildContext context, LabSettings settings) {
    final backdrop = LabScene.backdrop;
    if (backdrop == null) return null;
    return WaterGlass(
      key: _key,
      backdrop: backdrop,
      quality: settings.quality,
      dark: settings.dark,
      fog: _fog,
      refraction: _refraction,
      rain: RainSettings(dropsPerSecond: _rain),
    );
  }

  @override
  List<Widget> controls(BuildContext context, VoidCallback refresh, bool dark) => [
        LabSlider(label: 'Buée', value: _fog, min: 0, max: 1, dark: dark, onChanged: (v) {
          _fog = v;
          refresh();
        }),
        LabSlider(label: 'Pluie', value: _rain, min: 0, max: 30, unit: '/s', dark: dark, onChanged: (v) {
          _rain = v;
          refresh();
        }),
        LabSlider(label: 'Réfraction', value: _refraction, min: 40, max: 600, unit: ' px', dark: dark, onChanged: (v) {
          _refraction = v;
          refresh();
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              _key = UniqueKey();
              refresh();
            },
            child: const Text('Nouvelle vitre'),
          ),
        ),
      ];
}
