/// Les quatre niveaux de qualité de Droplet Matter.
///
/// LOW n'exécute aucun shader : un rendu de repli dessiné au canevas.
/// BALANCED : un échantillon, pas de dispersion ni de dépoli.
/// HIGH : dispersion chromatique, dépoli à 6 échantillons.
/// ULTRA : dépoli à 12 échantillons.
enum MatterQuality {
  low('LOW', 0),
  balanced('BALANCED', 1),
  high('HIGH', 2),
  ultra('ULTRA', 3);

  const MatterQuality(this.label, this.uniform);

  final String label;

  /// Valeur transmise à l'uniforme `uQuality` des shaders.
  final double uniform;

  bool get usesShader => this != MatterQuality.low;

  static MatterQuality fromName(String? name) {
    switch (name?.toLowerCase()) {
      case 'low':
      case '0':
        return MatterQuality.low;
      case 'balanced':
      case '1':
        return MatterQuality.balanced;
      case 'ultra':
      case '3':
        return MatterQuality.ultra;
      default:
        return MatterQuality.high;
    }
  }

  /// Niveau inférieur, utilisé par la baisse automatique quand les images ratent leur budget.
  MatterQuality get lower => switch (this) {
        MatterQuality.ultra => MatterQuality.high,
        MatterQuality.high => MatterQuality.balanced,
        _ => MatterQuality.low,
      };
}
