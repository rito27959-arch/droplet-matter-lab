// Les quelques pièces de l'application Droplet dont ont besoin le bouton de
// verre et la vitre embuée, réduites à l'essentiel pour le laboratoire.
// Les fichiers bouton_verre.dart, simulation_eau.dart et vitre_embuee.dart
// sont des COPIES de l'application : seuls leurs imports changent.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motor/motor.dart';

class OuroColors {
  static bool isDark = true;
  static Color get accent => const Color(0xFF0A84FF);
  static Color get accentRempli => const Color(0xFF0A84FF);
  static Color get texteSurAccent => Colors.white;
  static Color get label => isDark ? Colors.white : Colors.black;
  static Color get secondaryLabel => isDark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
  static Color get tertiaryLabel => isDark ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43);
  static Color get quaternarySystemFill => isDark ? const Color(0x2E767680) : const Color(0x14747480);
  static Color get secondarySystemBackground => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  static Color get systemBackground => isDark ? Colors.black : Colors.white;
  static Color get separator => isDark ? const Color(0x99545458) : const Color(0x4A3C3C43);
}

class OuroHaptics {
  static void selection() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
}

class OuroMotion {
  const OuroMotion({required this.reduceMotion});
  final bool reduceMotion;
  static OuroMotion of(BuildContext context) => OuroMotion(reduceMotion: MediaQuery.disableAnimationsOf(context));
  Motion get press => const CupertinoMotion.interactive();
  Motion get playful => const CupertinoMotion.bouncy();
}

class Flou extends StatelessWidget {
  const Flou({super.key, required this.filter, this.child});
  final ui.ImageFilter filter;
  final Widget? child;
  @override
  Widget build(BuildContext context) => BackdropFilter(filter: filter, child: child);
}

class OuroSpinner extends StatelessWidget {
  const OuroSpinner({super.key, this.color, this.radius = 10});
  final Color? color;
  final double radius;
  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: radius * 2, child: CircularProgressIndicator(strokeWidth: 2.2, color: color));
}

class OuroTypography {
  static const TextStyle headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4);
}

class DeviceProfile {
  static bool get sansShader => false;
  static bool get menager => false;
}

class StorageService {
  static final Map<String, String> _m = {};
  static String? getString(String k) => _m[k];
  static Future<void> setString(String k, String v) async => _m[k] = v;
  static Future<void> remove(String k) async => _m.remove(k);
}
