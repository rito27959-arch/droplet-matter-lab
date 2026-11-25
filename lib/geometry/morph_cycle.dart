/// Le cycle des formes de Droplet Geometry : sphère, pavé, goutte, grappe.
///
/// Une unité de cycle = une forme. Dans chaque unité, la forme est tenue
/// pendant 55 % du temps puis glisse vers la suivante (le shader applique la
/// même courbe). Avec les animations réduites, le cycle s'arrête sur la forme
/// courante et ne change que sur demande.
class MorphCycle {
  const MorphCycle({this.secondsPerShape = 3.2});

  final double secondsPerShape;

  static const shapes = ['Sphère', 'Pavé', 'Goutte', 'Grappe'];

  double at(double seconds) => seconds / secondsPerShape;

  /// Index de la forme tenue à cette position du cycle.
  static int shapeIndex(double cycle) => cycle.floor() % shapes.length;

  static String shapeName(double cycle) => shapes[shapeIndex(cycle)];
}
