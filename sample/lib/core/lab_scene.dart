import 'dart:ui' as ui;

import 'package:droplet_glass/droplet_glass.dart';

/// Le contenu d'exemple que la matière et l'eau recouvrent : une liste de
/// discussions sur un coucher de soleil. Chargé une fois au démarrage.
abstract final class LabScene {
  static const asset = 'assets/images/scene.jpg';
  static Backdrop? backdrop;

  static ui.Image? get image => backdrop?.sharp;

  static Future<void> load() async {
    try {
      backdrop ??= await Backdrop.fromAsset(asset);
    } catch (_) {
      // Sans image, les expériences concernées passent en rendu de repli.
    }
  }
}
