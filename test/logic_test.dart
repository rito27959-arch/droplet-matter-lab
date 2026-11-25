import 'dart:io';
import 'dart:ui';

import 'package:droplet_matter_lab/core/quality.dart';
import 'package:droplet_matter_lab/geometry/morph_cycle.dart';
import 'package:droplet_matter_lab/motion/spring.dart';
import 'package:droplet_matter_lab/rendering/uniforms.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compte les flottants déclarés par un shader généré, dans l'ordre.
int floatUniforms(String path) {
  final re = RegExp(r'^uniform\s+(float|vec2|vec3|vec4)\s+\w+;', multiLine: true);
  var n = 0;
  for (final m in re.allMatches(File(path).readAsStringSync())) {
    n += switch (m.group(1)) { 'float' => 1, 'vec2' => 2, 'vec3' => 3, _ => 4 };
  }
  return n;
}

void main() {
  group('Uniformes', () {
    test('chaque shader déclare l\'en-tête commun puis ses propres uniformes', () {
      // Doit rester égal à ce qu'écrit chaque expérience dans writeUniforms.
      const expected = {
        'shaders/e01_prismatic_surface.frag': headerFloatCount + 10,
        'shaders/e02_morphing_object.frag': headerFloatCount + 1,
        'shaders/e03_aether_atmosphere.frag': headerFloatCount,
        'shaders/e04_prismatic_morph.frag': headerFloatCount + 5,
        'shaders/e05_interactive_matter.frag': headerFloatCount + 5,
        'shaders/e06_signature.frag': headerFloatCount + 1,
      };
      expected.forEach((path, count) => expect(floatUniforms(path), count, reason: path));
    });
  });

  group('Ressorts', () {
    test('le ressort 2D atteint sa cible et s\'y arrête', () {
      final s = Spring2D(position: Offset.zero);
      s.target = const Offset(100, -40);
      for (var i = 0; i < 240; i++) {
        s.step(1 / 60);
      }
      expect((s.position - s.target).distance, lessThan(0.5));
      expect(s.isAtRest, isTrue);
    });

    test('une image très lente ne fait pas diverger le ressort', () {
      final s = Spring1D(stiffness: 320, dampingRatio: 0.6);
      s.target = 1;
      s.step(5); // borné à 0,1 s, intégré par sous-pas
      expect(s.value.isFinite, isTrue);
      expect(s.value, lessThan(2));
    });
  });

  group('Qualité et formes', () {
    test('la baisse automatique descend d\'un cran jusqu\'à LOW', () {
      expect(MatterQuality.ultra.lower, MatterQuality.high);
      expect(MatterQuality.high.lower, MatterQuality.balanced);
      expect(MatterQuality.balanced.lower, MatterQuality.low);
      expect(MatterQuality.low.usesShader, isFalse);
      expect(MatterQuality.fromName('ULTRA'), MatterQuality.ultra);
      expect(MatterQuality.fromName(null), MatterQuality.high);
    });

    test('le cycle des formes tourne sur quatre formes', () {
      const m = MorphCycle(secondsPerShape: 2);
      expect(MorphCycle.shapeName(m.at(0)), 'Sphère');
      expect(MorphCycle.shapeName(m.at(4.5)), 'Goutte');
      expect(MorphCycle.shapeName(m.at(8.1)), 'Sphère');
    });
  });
}
