import 'dart:ui' as ui;

/// Les shaders Droplet, compilés une seule fois et gardés en cache.
///
/// Charger un `FragmentProgram` coûte : on le fait au démarrage, jamais pendant
/// une animation. Un shader qui échoue est mémorisé comme indisponible, et
/// l'appelant passe en rendu de repli au lieu de planter.
class ShaderLibrary {
  ShaderLibrary._();

  static final ShaderLibrary instance = ShaderLibrary._();

  static const _root = 'packages/droplet_glass/shaders';
  static const prismaticSurface = '$_root/e01_prismatic_surface.frag';
  static const morphingObject = '$_root/e02_morphing_object.frag';
  static const aetherAtmosphere = '$_root/e03_aether_atmosphere.frag';
  static const prismaticMorph = '$_root/e04_prismatic_morph.frag';
  static const interactiveMatter = '$_root/e05_interactive_matter.frag';
  static const signature = '$_root/e06_signature.frag';
  static const waterGlass = '$_root/water_glass.frag';
  static const liquidBar = '$_root/liquid_bar.frag';

  static const all = [
    prismaticSurface,
    morphingObject,
    aetherAtmosphere,
    prismaticMorph,
    interactiveMatter,
    signature,
    waterGlass,
    liquidBar,
  ];

  final Map<String, ui.FragmentProgram> _programs = {};
  final Map<String, Object> _failures = {};

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

  Future<void> warmUp() => Future.wait([for (final a in all) load(a)]);
}
