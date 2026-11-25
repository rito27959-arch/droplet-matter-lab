// COPIE de l'application Droplet (design_system/bouton_verre.dart) — seuls les imports changent.
// ============================================================================
// LE BOUTON DE VERRE — le bouton de Droplet, partout où il compte.
// ----------------------------------------------------------------------------
// Le modèle : « Débloquer pour 1 000 F » de la vitrine Droplet Pro (la pilule
// pleine, teintée de l'accent, posée sur du verre), avec le comportement
// des boutons de verre d'iOS 27 tels que WhatsApp les emploie :
//
//   • LA MATIÈRE. Un verre teinté (ou clair) qui laisse passer le fond flou,
//     un lisere de lumière en haut à gauche, un reflet plus sombre en bas.
//   • L'APPUI. Le verre GONFLE légèrement sous le doigt au lieu de
//     s'enfoncer — c'est la signature d'iOS 27 —, s'éclaire, et une tache de
//     lumière suit le doigt à l'intérieur, comme une goutte posée sur la
//     vitre. Au relâchement, un ressort le ramène, avec un léger dépassement.
//   • LA MAIN. Un petit choc (sélection) quand le doigt se pose, un choc
//     léger quand l'action part. Rien si le bouton est inactif.
//
// Deux formes : la PILULE (bouton principal, pleine largeur) et le ROND
// (icône seule : le « + » des discussions, retour, fermer).
//
// Accessibilité : « Réduire les animations » garde la lumière mais retire
// le gonflement ; en effets allégés, le flou est remplacé par un fond plein
// (voir `Flou`). Le libellé est annoncé comme un bouton.
// ============================================================================

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

import 'compat.dart';

enum FormeVerre { pilule, rond }

class BoutonVerre extends StatefulWidget {
  const BoutonVerre({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.forme = FormeVerre.pilule,
    this.teinte,
    this.hauteur = 54,
    this.largeur,
    this.semantique,
    this.gonflement,
  });

  /// La pilule pleine de l'accent, comme « Débloquer » : le bouton principal
  /// d'un écran. [occupe] remplace le libellé par la roue d'attente.
  factory BoutonVerre.principal({
    Key? key,
    required String libelle,
    required VoidCallback? onTap,
    bool occupe = false,
    double hauteur = 54,
  }) {
    return BoutonVerre(
      key: key,
      onTap: occupe ? null : onTap,
      teinte: onTap == null && !occupe ? null : OuroColors.accentRempli,
      hauteur: hauteur,
      largeur: double.infinity,
      semantique: libelle,
      child: occupe
          ? SizedBox(
              width: 22,
              height: 22,
              child: OuroSpinner(color: OuroColors.texteSurAccent, radius: 11),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                libelle,
                key: ValueKey(libelle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OuroTypography.headline.copyWith(
                  color: onTap == null ? OuroColors.tertiaryLabel : OuroColors.texteSurAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }

  /// Le rond de verre portant une icône (retour, fermer, « + »).
  /// Sans [teinte] : verre clair et icône à l'encre du texte.
  factory BoutonVerre.rond({
    Key? key,
    required IconData icone,
    required VoidCallback? onTap,
    required String semantique,
    VoidCallback? onLongPress,
    Color? teinte,
    double diametre = 44,
    double tailleIcone = 22,
  }) {
    return BoutonVerre(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      forme: FormeVerre.rond,
      teinte: teinte,
      hauteur: diametre,
      largeur: diametre,
      semantique: semantique,
      child: Icon(
        icone,
        size: tailleIcone,
        color: teinte != null ? OuroColors.texteSurAccent : OuroColors.label,
      ),
    );
  }

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final FormeVerre forme;

  /// La couleur du verre. `null` : verre clair, neutre.
  final Color? teinte;
  final double hauteur;

  /// `null` : la largeur du contenu ; `double.infinity` : toute la place.
  final double? largeur;
  final String? semantique;

  /// De combien le verre grandit sous le doigt (0,04 = 4 %). Par défaut :
  /// 12 % pour un rond, 3 % pour une pilule — une grande surface qui
  /// gonflerait autant qu'une petite paraîtrait sauter.
  final double? gonflement;

  @override
  State<BoutonVerre> createState() => _BoutonVerreState();
}

class _BoutonVerreState extends State<BoutonVerre> {
  bool _appuye = false;

  /// Le doigt, en coordonnées relatives (0..1) dans le bouton.
  Offset _doigt = const Offset(0.5, 0.5);

  bool get _actif => widget.onTap != null || widget.onLongPress != null;

  void _poser(Offset local, Size taille) {
    if (!_actif) return;
    OuroHaptics.selection();
    setState(() {
      _appuye = true;
      _doigt = _relatif(local, taille);
    });
  }

  Offset _relatif(Offset local, Size taille) => Offset(
        (local.dx / taille.width).clamp(0.0, 1.0),
        (local.dy / taille.height).clamp(0.0, 1.0),
      );

  void _lever() {
    if (_appuye && mounted) setState(() => _appuye = false);
  }

  @override
  Widget build(BuildContext context) {
    final motion = OuroMotion.of(context);
    final rond = widget.forme == FormeVerre.rond;
    final gonfle = motion.reduceMotion ? 0.0 : (widget.gonflement ?? (rond ? 0.12 : 0.03));
    final rayon = BorderRadius.circular(widget.hauteur / 2);

    final corps = LayoutBuilder(builder: (context, box) {
      final taille = Size(
        box.maxWidth.isFinite ? box.maxWidth : widget.hauteur,
        widget.hauteur,
      );
      return Listener(
        onPointerDown: (e) => _poser(e.localPosition, taille),
        onPointerMove: (e) {
          if (_appuye) setState(() => _doigt = _relatif(e.localPosition, taille));
        },
        onPointerUp: (_) => _lever(),
        onPointerCancel: (_) => _lever(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null
              ? null
              : () {
                  OuroHaptics.light();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  OuroHaptics.medium();
                  widget.onLongPress!();
                },
          child: SingleMotionBuilder(
            value: _appuye ? 1 : 0,
            motion: _appuye ? motion.press : motion.playful,
            builder: (context, p, enfant) {
              // Le ressort de relâchement dépasse un peu : on le laisse
              // passer sous 1 (le verre se « pose »), jamais sous 0,97.
              final echelle = (1 + gonfle * p).clamp(0.97, 1 + gonfle * 1.2);
              return Transform.scale(
                scale: echelle,
                child: _Verre(
                  rayon: rayon,
                  teinte: widget.teinte,
                  actif: _actif,
                  appui: p.clamp(0.0, 1.0),
                  doigt: _doigt,
                  child: enfant!,
                ),
              );
            },
            child: SizedBox(
              height: widget.hauteur,
              width: widget.largeur,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: rond ? 0 : 22),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      );
    });

    return Semantics(
      button: true,
      enabled: _actif,
      label: widget.semantique,
      excludeSemantics: widget.semantique != null,
      onTap: widget.onTap,
      child: SizedBox(
        height: widget.hauteur,
        width: widget.largeur,
        child: corps,
      ),
    );
  }
}

/// La matière : fond flou, teinte, lisere de lumière et tache sous le doigt.
class _Verre extends StatelessWidget {
  const _Verre({
    required this.rayon,
    required this.teinte,
    required this.actif,
    required this.appui,
    required this.doigt,
    required this.child,
  });

  final BorderRadius rayon;
  final Color? teinte;
  final bool actif;
  final double appui;
  final Offset doigt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sombre = OuroColors.isDark;
    final Color fond;
    if (!actif && teinte == null) {
      fond = OuroColors.quaternarySystemFill;
    } else if (teinte != null) {
      // Le verre teinté reste un VERRE : presque opaque, mais le fond
      // transparaît sur les bords grâce au dégradé ci-dessous.
      fond = teinte!.withValues(alpha: 0.92);
    } else {
      fond = sombre ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.55);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rayon,
        boxShadow: [
          if (actif)
            BoxShadow(
              color: (teinte ?? Colors.black).withValues(alpha: sombre ? 0.30 : 0.18 + 0.06 * appui),
              blurRadius: 18 + 8 * appui,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: rayon,
        child: Flou(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: CustomPaint(
            painter: _PeintreVerre(
              rayon: rayon,
              fond: fond,
              teinte: teinte != null,
              sombre: sombre,
              appui: appui,
              doigt: doigt,
              actif: actif,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PeintreVerre extends CustomPainter {
  _PeintreVerre({
    required this.rayon,
    required this.fond,
    required this.teinte,
    required this.sombre,
    required this.appui,
    required this.doigt,
    required this.actif,
  });

  final BorderRadius rayon;
  final Color fond;
  final bool teinte;
  final bool sombre;
  final double appui;
  final Offset doigt;
  final bool actif;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = rayon.toRRect(r);

    // 1. Le corps du verre, un peu plus clair en haut qu'en bas : la
    //    lumière vient d'au-dessus.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
          Color.lerp(fond, Colors.white, teinte ? 0.10 : 0.06)!,
          fond,
          Color.lerp(fond, Colors.black, teinte ? 0.10 : 0.03)!,
        ], [0, 0.55, 1]),
    );
    if (!actif) return;

    // 2. La lumière sous le doigt : une tache douce qui le suit, comme une
    //    goutte posée sur la vitre qui concentre le jour.
    if (appui > 0.01) {
      final c = Offset(doigt.dx * size.width, doigt.dy * size.height);
      final portee = size.shortestSide * 1.4;
      canvas.drawRRect(
        rr,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(c, portee, [
            Colors.white.withValues(alpha: (teinte ? 0.22 : 0.16) * appui),
            Colors.white.withValues(alpha: 0),
          ]),
      );
    }

    // 3. Le lisere : vif en haut à gauche, presque éteint au milieu, un
    //    second reflet plus faible en bas à droite (la lumière qui traverse
    //    l'épaisseur du verre et ressort de l'autre côté).
    final lisere = rr.deflate(0.5);
    canvas.drawRRect(
      lisere,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, [
          Colors.white.withValues(alpha: (sombre ? 0.42 : 0.70) + 0.2 * appui),
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: sombre ? 0.22 : 0.35),
        ], [0, 0.35, 0.7, 1]),
    );

    // 4. Un trait d'ombre intérieure tout en bas, très fin : l'épaisseur.
    if (!teinte) {
      canvas.drawRRect(
        lisere,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
            Colors.transparent,
            Colors.black.withValues(alpha: sombre ? 0.25 : 0.08),
          ], [0.6, 1]),
      );
    }
  }

  @override
  bool shouldRepaint(_PeintreVerre o) =>
      o.fond != fond || o.appui != appui || o.doigt != doigt || o.sombre != sombre || o.actif != actif;
}
