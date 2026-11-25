import 'package:flutter/foundation.dart';

import 'quality.dart';

/// Réglages globaux du laboratoire, partagés par toutes les expériences.
class LabSettings extends ChangeNotifier {
  LabSettings({
    this.quality = MatterQuality.high,
    this.dark = true,
    this.frozenTime,
    this.showFrameStats = true,
    this.adaptiveQuality = true,
  });

  MatterQuality quality;
  bool dark;

  /// Temps figé (secondes) pour les captures reproductibles ; null = temps réel.
  final double? frozenTime;

  bool showFrameStats;

  /// Baisse la qualité d'un cran quand le rendu rate son budget de façon durable.
  bool adaptiveQuality;

  void setQuality(MatterQuality value) {
    if (value == quality) return;
    quality = value;
    notifyListeners();
  }

  void setDark(bool value) {
    if (value == dark) return;
    dark = value;
    notifyListeners();
  }

  void toggleFrameStats() {
    showFrameStats = !showFrameStats;
    notifyListeners();
  }

  void setAdaptive(bool value) {
    adaptiveQuality = value;
    notifyListeners();
  }
}
