import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Les shaders du laboratoire, compilés une seule fois et gardés en cache.
///
/// Charger un `FragmentProgram` coûte : on le fait au démarrage, jamais pendant
/// une animation. Un shader qui échoue est mémorisé comme indisponible, et
/// l'expérience passe en rendu de repli au lieu de planter.
class ShaderLibrary {
  ShaderLibrary._();

  static final ShaderLibrary instance = ShaderLibrary._();

  static const prismaticSurface = 'shaders/e01_prismatic_surface.frag';
  static const morphingObject = 'shaders/e02_morphing_object.frag';
  static const aetherAtmosphere = 'shaders/e03_aether_atmosphere.frag';
  static const prismaticMorph = 'shaders/e04_prismatic_morph.frag';
  static const interactiveMatter = 'shaders/e05_interactive_matter.frag';
  static const signature = 'shaders/e06_signature.frag';

  static const all = [
    prismaticSurface,
    morphingObject,
    aetherAtmosphere,
    prismaticMorph,
    interactiveMatter,
    signature,
  ];

  final Map<String, ui.FragmentProgram> _programs = {};
  final Map<String, Object> _failures = {};
  ui.Image? _scene;

  ui.Image? get scene => _scene;

  Object? failureOf(String asset) => _failures[asset];

  ui.FragmentProgram? program(String asset) => _programs[asset];

  Future<ui.FragmentProgram?> load(String asset) async {
    if (_programs.containsKey(asset)) return _programs[asset];
    if (_failures.containsKey(asset)) return null;
    try {
      final program = await ui.FragmentProgram.fromAsset(asset);
      _programs[asset] = program;
      return program;
    } catch (error) {
      _failures[asset] = error;
      return null;
    }
  }

  Future<void> warmUp() async {
    await Future.wait([for (final a in all) load(a), _loadScene()]);
  }

  Future<void> _loadScene() async {
    if (_scene != null) return;
    final data = await rootBundle.load('assets/images/scene.jpg');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _scene = frame.image;
  }
}
