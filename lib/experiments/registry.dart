import 'e01_prismatic_surface.dart';
import 'e02_morphing_object.dart';
import 'e03_aether_atmosphere.dart';
import 'e04_prismatic_morph.dart';
import 'e05_interactive_matter.dart';
import 'e06_signature.dart';
import 'experiment.dart';

/// Toutes les expériences, dans l'ordre du laboratoire.
final List<ExperimentLogic Function()> experimentFactories = [
  PrismaticSurface.new,
  MorphingObject.new,
  AetherAtmosphere.new,
  PrismaticMorph.new,
  InteractiveMatter.new,
  Signature.new,
];
