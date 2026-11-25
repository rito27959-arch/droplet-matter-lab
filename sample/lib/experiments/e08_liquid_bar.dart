import 'package:droplet_glass/droplet_glass.dart';
import 'package:droplet_ui/droplet_ui.dart';
import 'package:flutter/material.dart';

import '../core/lab_scene.dart';
import '../core/lab_settings.dart';
import 'experiment.dart';

/// Expérience 08 — barre d'onglets en verre liquide, sur un contenu qui défile.
class LiquidBar extends ExperimentLogic {
  @override
  int get number => 8;
  @override
  String get title => 'Barre liquide';
  @override
  String get summary =>
      'Le verre courbe la lumière au bord et grossit sous la sélection. Faites glisser la lentille d’un onglet à l’autre ; faites défiler le contenu dessous.';
  @override
  String get shaderAsset => ShaderLibrary.liquidBar;

  @override
  void writeUniforms(UniformWriter w, FrameContext f) {}

  @override
  Widget? body(BuildContext context, LabSettings settings) {
    final backdrop = LabScene.backdrop;
    if (backdrop == null) return null;
    return LiquidTabBar(
      backdrop: backdrop,
      quality: settings.quality,
      dark: settings.dark,
      // Au-dessus du panneau de réglages du laboratoire.
      bottomInset: 92,
      tabs: const [
        LiquidTab(icon: Icons.chat_bubble_rounded, label: 'Discussions'),
        LiquidTab(icon: Icons.call_rounded, label: 'Appels'),
        LiquidTab(icon: Icons.auto_awesome_rounded, label: 'Moments'),
        LiquidTab(icon: Icons.person_rounded, label: 'Profil'),
      ],
    );
  }
}
