import 'package:droplet_core/droplet_core.dart';

/// Les paramètres de Droplet Matter, et leurs valeurs par niveau de qualité.
///
/// Les valeurs ont été réglées à l'œil dans le banc d'essai WebGL ; elles
/// doivent être revues sur de vrais téléphones (voir documentation/performance.md).
class MatterParams {
  const MatterParams({
    required this.refraction,
    required this.dispersion,
    required this.frost,
    required this.tint,
  });

  /// Déviation maximale au bord, en pixels logiques.
  final double refraction;

  /// Écart entre les longueurs d'onde (0 à 0,6). Ignoré en BALANCED.
  final double dispersion;

  /// Rayon du dépoli, en pixels. Ignoré en BALANCED.
  final double frost;

  /// Quantité de teinte de surface (0 à 1).
  final double tint;

  MatterParams copyWith({double? refraction, double? dispersion, double? frost, double? tint}) => MatterParams(
        refraction: refraction ?? this.refraction,
        dispersion: dispersion ?? this.dispersion,
        frost: frost ?? this.frost,
        tint: tint ?? this.tint,
      );

  /// Préréglage de la surface prismatique (expérience 01).
  static MatterParams surfaceFor(MatterQuality q) => switch (q) {
        MatterQuality.ultra => const MatterParams(refraction: 20, dispersion: 0.35, frost: 9, tint: 0.14),
        MatterQuality.high => const MatterParams(refraction: 20, dispersion: 0.30, frost: 8, tint: 0.16),
        _ => const MatterParams(refraction: 16, dispersion: 0, frost: 0, tint: 0.30),
      };
}
