import 'package:flutter/animation.dart';

/// Jetons de mouvement de Droplet Motion.
///
/// Règle : chaque mouvement dit quelque chose. Ce qui change d'état utilise la
/// courbe standard ; ce qui entre décélère ; ce que le doigt lâche suit un
/// ressort (`Spring2D`). Aucune animation ne retarde une action : la cible
/// d'interaction répond dans la même image, l'animation suit.
abstract final class MotionTokens {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration short = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration long = Duration(milliseconds: 380);

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve enter = Cubic(0.1, 0.9, 0.2, 1);
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// Ressorts nommés : (raideur, amortissement).
  static const ({double stiffness, double damping}) springFollow = (stiffness: 180, damping: 0.72);
  static const ({double stiffness, double damping}) springPress = (stiffness: 320, damping: 0.62);
  static const ({double stiffness, double damping}) springLight = (stiffness: 60, damping: 0.95);
}
