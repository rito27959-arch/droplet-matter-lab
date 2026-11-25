import 'dart:ui';

import 'package:flutter/material.dart';

/// Habillage du laboratoire : la base Quiet Futurism sur laquelle la matière se pose.
/// Neutres froids, une seule encre, aucune couleur d'accent : la couleur vient
/// de la lumière des expériences, pas de l'interface.
class LabColors {
  const LabColors._({
    required this.background,
    required this.ink,
    required this.muted,
    required this.hairline,
    required this.panel,
  });

  final Color background;
  final Color ink;
  final Color muted;
  final Color hairline;
  final Color panel;

  static const dark = LabColors._(
    background: Color(0xFF05070A),
    ink: Color(0xFFEDF1F4),
    muted: Color(0xFF8D97A1),
    hairline: Color(0xFF1D242B),
    panel: Color(0xCC0B0F13),
  );

  static const light = LabColors._(
    background: Color(0xFFE6EAEE),
    ink: Color(0xFF0E1216),
    muted: Color(0xFF59626B),
    hairline: Color(0xFFC9D0D6),
    panel: Color(0xD9F3F5F7),
  );

  static LabColors of(bool dark) => dark ? LabColors.dark : LabColors.light;
}

abstract final class LabType {
  static const family = 'packages/droplet_core/Commissioner';
  static const mono = 'packages/droplet_core/MartianMono';

  /// Titre évasé : l'axe Flair de Commissioner, la signature typographique.
  static TextStyle display(Color color, {double size = 34, double flair = 70}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        height: 1.08,
        letterSpacing: -0.02 * size,
        color: color,
        fontVariations: [FontVariation('wght', 640), FontVariation('FLAR', flair), FontVariation('VOLM', 30)],
      );

  static TextStyle body(Color color, {double size = 15, double weight = 400}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        height: 1.45,
        color: color,
        fontVariations: [FontVariation('wght', weight)],
      );

  static TextStyle label(Color color, {double size = 13}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        height: 1.3,
        letterSpacing: 0.1,
        color: color,
        fontVariations: const [FontVariation('wght', 580)],
      );

  static TextStyle data(Color color, {double size = 12}) => TextStyle(
        fontFamily: mono,
        fontSize: size,
        height: 1.35,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures(), FontFeature.slashedZero()],
        fontVariations: const [FontVariation('wght', 430)],
      );
}

ThemeData labThemeData(bool dark) {
  final c = LabColors.of(dark);
  return ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.background,
    fontFamily: LabType.family,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C8A9E),
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(surface: c.background, onSurface: c.ink, primary: c.ink, onPrimary: c.background),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.ink,
      inactiveTrackColor: c.hairline,
      thumbColor: c.ink,
      overlayColor: c.ink.withValues(alpha: 0.08),
      trackHeight: 2,
    ),
  );
}
