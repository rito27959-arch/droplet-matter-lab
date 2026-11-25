import 'dart:math' as math;
import 'dart:ui';

import 'package:droplet_glass/droplet_glass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(390, 844);
  const still = RainSettings(dropsPerSecond: 0, condensationPerSecond: 0);

  test('deux gouttes qui se touchent fusionnent en conservant le volume', () {
    final sim = RainSimulation(size: size, settings: still)
      ..spawn(100, 100, 5)
      ..spawn(104, 102, 4);
    final before = sim.totalVolume;
    sim.time = 10; // hors de la phase de condensation initiale
    sim.step(1 / 60);
    expect(sim.drops, hasLength(1));
    expect(sim.drops.single.r, closeTo(math.pow(125 + 64, 1 / 3), 0.01));
    expect(sim.totalVolume, closeTo(before, 0.5));
  });

  test('une petite goutte adhère, une grosse glisse et laisse une traînée', () {
    final sim = RainSimulation(size: size, settings: still, seed: 3)
      ..spawn(80, 100, 4)
      ..spawn(250, 100, 14);
    sim.time = 10;
    for (var i = 0; i < 60; i++) {
      sim.step(1 / 60);
    }
    final small = sim.drops.firstWhere((d) => (d.x - 80).abs() < 5);
    expect(small.y, closeTo(100, 0.5));
    final big = sim.drops.reduce((a, b) => a.r > b.r ? a : b);
    expect(big.y, greaterThan(140));
    expect(sim.drops.length, greaterThan(2), reason: 'des gouttelettes de traînée');
  });

  test('le doigt ramasse l\'eau sur son passage', () {
    final sim = RainSimulation(size: size, settings: still)..spawn(200, 400, 5);
    sim.wipe(const Offset(150, 400), const Offset(250, 400));
    expect(sim.drops.where((d) => (d.x - 200).abs() < 2 && (d.y - 400).abs() < 2), isEmpty);
    expect(sim.pendingWipes, isNotEmpty);
  });

  test('la pluie ne dépasse jamais le nombre maximal de gouttes', () {
    final sim = RainSimulation(size: size, settings: const RainSettings(dropsPerSecond: 400, maxDrops: 120));
    for (var i = 0; i < 300; i++) {
      sim.step(1 / 30);
    }
    expect(sim.drops.length, lessThanOrEqualTo(120));
  });
}
