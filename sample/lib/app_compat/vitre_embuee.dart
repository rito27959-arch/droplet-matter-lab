// COPIE de l'application Droplet (shared/eau/vitre_embuee.dart) — seuls les imports changent.
// ============================================================================
// LA VITRE EMBUÉE — l'accueil quand on revient après une longue absence.
// ----------------------------------------------------------------------------
// Si l'on n'a pas ouvert Droplet depuis au moins TROIS HEURES, l'écran des
// discussions apparaît derrière une vitre embuée, avec quelques gouttes qui
// glissent : l'eau de Droplet Matter Lab (même simulation, même shader). Le
// doigt l'essuie, comme une vraie fenêtre. Dès que la vitre est assez propre
// — ou si l'on ne la touche pas — la buée s'évapore toute seule et l'écran
// redevient normal. Cela ne dure jamais plus de quelques secondes.
//
// Ce qui la garde légère :
//   • elle n'existe QUE pendant ces quelques secondes : pas de minuterie,
//     pas d'image, pas de shader le reste du temps ;
//   • le fond est UNE photo de l'écran prise au départ, et sa version floue
//     est calculée une seule fois, en petit ;
//   • les cartes d'eau sont à 40 % de la résolution ; au plus 140 gouttes ;
//   • sur un téléphone modeste (pas de shader), une version dessinée simple :
//     buée, gouttes et traces du doigt, sans réfraction.
//
// Ce qui la rend sûre :
//   • jamais avec un lecteur d'écran (elle prend les touchers) ;
//   • « Réduire les animations » : la vitre reste immobile, seul le doigt
//     agit, et elle s'évapore sans mouvement ;
//   • jamais au premier lancement, ni pendant l'ouverture animée.
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'compat.dart';
import 'simulation_eau.dart';

class VitreEmbuee extends StatefulWidget {
  const VitreEmbuee({super.key, required this.child, this.attendre, this.declencheur});

  final Widget child;

  /// Embue la vitre tout de suite à chaque notification, sans attendre trois
  /// heures (aperçu dans les réglages, essais, laboratoire).
  final Listenable? declencheur;

  /// Vrai tant qu'il faut attendre (l'ouverture animée de l'app).
  final ValueListenable<bool>? attendre;

  /// Le temps passé hors de l'app à partir duquel la vitre s'embue.
  static const Duration absenceMinimale = Duration(hours: 3);

  static const String _cleSortie = 'vitre_derniere_sortie';

  static Future<void> charger() => _chargement ??= ui.FragmentProgram.fromAsset('shaders/eau_vitre.frag')
      .then<void>((p) => _programme = p)
      .catchError((Object _) {});

  static ui.FragmentProgram? _programme;
  static Future<void>? _chargement;

  @override
  State<VitreEmbuee> createState() => _VitreEmbueeState();
}

enum _Phase { aucune, entree, active, evaporation, sortie }

class _VitreEmbueeState extends State<VitreEmbuee> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final GlobalKey _cle = GlobalKey();
  late final Ticker _ticker = createTicker(_tic);
  final ValueNotifier<int> _repeindre = ValueNotifier(0);

  _Phase _phase = _Phase.aucune;
  RainSimulation? _sim;
  WaterMaps? _cartes;
  ui.Image? _nette;
  ui.Image? _floue;
  ui.FragmentShader? _shader;

  /// Les traits du doigt, pour la version sans shader.
  final Path _traces = Path();
  Offset? _doigt;
  double _parcours = 0;

  Duration _dernier = Duration.zero;
  double _t = 0; // secondes depuis le début
  double _tPhase = 0; // secondes depuis le début de la phase
  double _dernierToucher = 0;
  bool _touchee = false;
  double _fondu = 0;
  double _buee = 1;
  bool _mouvement = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.declencheur?.addListener(_forcer);
    unawaited(VitreEmbuee.charger());
    // Démarrage à froid : l'absence se lit depuis la dernière sortie notée.
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifierAbsence());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    switch (etat) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _noterSortie();
      case AppLifecycleState.resumed:
        _verifierAbsence();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void didUpdateWidget(VitreEmbuee old) {
    super.didUpdateWidget(old);
    if (old.declencheur != widget.declencheur) {
      old.declencheur?.removeListener(_forcer);
      widget.declencheur?.addListener(_forcer);
    }
  }

  void _forcer() => unawaited(_embuer());

  void _noterSortie() {
    // Une seule note par sortie : « caché » puis « en pause » ne doivent pas
    // repousser l'heure de départ.
    if (StorageService.getString(VitreEmbuee._cleSortie) != null) return;
    unawaited(StorageService.setString(VitreEmbuee._cleSortie, DateTime.now().millisecondsSinceEpoch.toString()));
  }

  void _verifierAbsence() {
    final brut = StorageService.getString(VitreEmbuee._cleSortie);
    if (brut == null) return;
    unawaited(StorageService.remove(VitreEmbuee._cleSortie));
    final sortie = int.tryParse(brut);
    if (sortie == null) return;
    final absence = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(sortie));
    if (absence >= VitreEmbuee.absenceMinimale) unawaited(_embuer());
  }

  Future<void> _embuer() async {
    if (!mounted || _phase != _Phase.aucune) return;
    final media = MediaQuery.maybeOf(context);
    if (media == null || media.accessibleNavigation) return;
    // Seulement si l'écran des discussions est vraiment devant les yeux.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;

    // L'ouverture animée d'abord : la vitre s'embue ensuite.
    final attente = widget.attendre;
    if (attente != null && attente.value) {
      final fini = Completer<void>();
      void ecoute() {
        if (!attente.value && !fini.isCompleted) fini.complete();
      }

      attente.addListener(ecoute);
      await fini.future.timeout(const Duration(seconds: 6), onTimeout: () {});
      attente.removeListener(ecoute);
      if (!mounted) return;
    }

    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return;
    final boite = _cle.currentContext?.findRenderObject();
    if (boite is! RenderRepaintBoundary || boite.size.isEmpty) return;

    final ratio = math.min(media.devicePixelRatio, 2.0) * 0.75;
    final nette = await boite.toImage(pixelRatio: ratio);
    if (!mounted) {
      nette.dispose();
      return;
    }
    _nette = nette;
    _floue = _flouter(nette);

    await VitreEmbuee.charger();
    final programme = VitreEmbuee._programme;
    _shader = (!DeviceProfile.sansShader && programme != null) ? programme.fragmentShader() : null;

    _mouvement = !media.disableAnimations;
    final taille = boite.size;
    final sim = RainSimulation(
      size: taille,
      seed: DateTime.now().millisecond,
      settings: const RainSettings(
        dropsPerSecond: 2.5,
        maxRadius: 12,
        fogReturnSeconds: 1e9, // ce qui est essuyé reste essuyé
        condensationPerSecond: 30,
        fingerRadius: 26,
        maxDrops: 140,
      ),
    );
    // La vitre n'est pas vide quand on arrive : une nuit de condensation.
    for (var t = 0.0; t < 6; t += 1 / 30) {
      sim.step(1 / 30);
    }
    sim.settings = sim.settings.copyWith(dropsPerSecond: 0.6);
    _sim = sim;
    _cartes = WaterMaps(scale: 0.4)..update(sim);

    _t = 0;
    _tPhase = 0;
    _dernierToucher = 0;
    _touchee = false;
    _buee = 1;
    _fondu = 0;
    _traces.reset();
    _dernier = Duration.zero;
    setState(() => _phase = _Phase.entree);
    _ticker.start();
  }

  /// La version floue du fond, en petit, une seule fois.
  ui.Image _flouter(ui.Image source) {
    const echelle = 0.25;
    final w = math.max(1, (source.width * echelle).round());
    final h = math.max(1, (source.height * echelle).round());
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.scale(echelle);
    c.drawImage(
      source,
      Offset.zero,
      ui.Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: ui.TileMode.clamp),
    );
    return rec.endRecording().toImageSync(w, h);
  }

  void _tic(Duration maintenant) {
    final dt = _dernier == Duration.zero ? 1 / 60 : ((maintenant - _dernier).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _dernier = maintenant;
    _t += dt;
    _tPhase += dt;
    final sim = _sim;
    if (sim == null) return;

    switch (_phase) {
      case _Phase.entree:
        _fondu = Curves.easeOut.transform((_tPhase / 0.5).clamp(0.0, 1.0));
        if (_tPhase >= 0.5) _changer(_Phase.active);
      case _Phase.active:
        final calme = _t - _dernierToucher;
        if (sim.essuye >= 0.5) {
          _changer(_Phase.sortie);
        } else if ((!_touchee && _t > 7) || (_touchee && calme > 4) || _t > 30) {
          _changer(_Phase.evaporation);
        }
      case _Phase.evaporation:
        // La buée s'en va d'abord, puis le reste s'efface.
        _buee = 1 - Curves.easeInOut.transform((_tPhase / 2.2).clamp(0.0, 1.0));
        _fondu = 1 - Curves.easeIn.transform(((_tPhase - 1.6) / 0.8).clamp(0.0, 1.0));
        if (_tPhase >= 2.4) _terminer();
      case _Phase.sortie:
        _fondu = 1 - Curves.easeInOut.transform((_tPhase / 0.45).clamp(0.0, 1.0));
        if (_tPhase >= 0.45) _terminer();
      case _Phase.aucune:
        return;
    }
    if (_phase == _Phase.aucune) return;

    if (_mouvement) sim.step(dt);
    _cartes?.update(sim);
    _repeindre.value++;
  }

  void _changer(_Phase p) {
    _phase = p;
    _tPhase = 0;
    // Les touchers passent de nouveau à l'écran dès que l'eau s'en va.
    if (p == _Phase.evaporation || p == _Phase.sortie) setState(() {});
  }

  void _terminer() {
    _ticker.stop();
    _cartes?.dispose();
    _cartes = null;
    _nette?.dispose();
    _floue?.dispose();
    _nette = _floue = null;
    _shader?.dispose();
    _shader = null;
    _sim = null;
    if (mounted) setState(() => _phase = _Phase.aucune);
  }

  void _essuyer(Offset vers) {
    final depuis = _doigt ?? vers;
    _doigt = vers;
    _sim?.wipe(depuis, vers);
    _traces
      ..moveTo(depuis.dx, depuis.dy)
      ..lineTo(vers.dx + 0.01, vers.dy);
    _touchee = true;
    _dernierToucher = _t;
    // Un petit grain sous le doigt, comme une vitre qui crisse.
    _parcours += (vers - depuis).distance;
    if (_parcours > 90) {
      _parcours = 0;
      OuroHaptics.selection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.declencheur?.removeListener(_forcer);
    _ticker.dispose();
    _repeindre.dispose();
    _cartes?.dispose();
    _nette?.dispose();
    _floue?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contenu = RepaintBoundary(key: _cle, child: widget.child);
    if (_phase == _Phase.aucune || _nette == null) return contenu;
    final prendTouchers = _phase == _Phase.entree || _phase == _Phase.active;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        contenu,
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              ignoring: !prendTouchers,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  _doigt = e.localPosition;
                  _essuyer(e.localPosition);
                },
                onPointerMove: (e) => _essuyer(e.localPosition),
                onPointerUp: (_) => _doigt = null,
                onPointerCancel: (_) => _doigt = null,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _shader != null
                      ? _PeintreEau(etat: this, repaint: _repeindre)
                      : _PeintreEauSimple(etat: this, repaint: _repeindre),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Le rendu complet : la vitre de Droplet Matter Lab (réfraction de chaque
/// goutte, reflets, buée).
class _PeintreEau extends CustomPainter {
  _PeintreEau({required this.etat, Listenable? repaint}) : super(repaint: repaint);

  final _VitreEmbueeState etat;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = etat._shader;
    final cartes = etat._cartes;
    final sim = etat._sim;
    final nette = etat._nette;
    final floue = etat._floue;
    if (shader == null || cartes == null || !cartes.ready || sim == null || nette == null || floue == null) return;

    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    // En-tête commun (voir shaders/eau_vitre.frag) — l'ordre compte.
    f(size.width);
    f(size.height);
    f(sim.time);
    f(DeviceProfile.menager ? 1 : 2); // qualité
    f(OuroColors.isDark ? 1 : 0);
    f(size.width * 0.8); // la lumière, en haut à droite
    f(size.height * 0.1);
    f(etat._mouvement ? 1 : 0);
    // Propres à l'eau.
    f(nette.width.toDouble());
    f(nette.height.toDouble());
    f(etat._buee);
    f(300); // réfraction
    f(14); // hauteur d'une goutte
    f(cartes.width.toDouble());
    f(cartes.heightPx.toDouble());
    f(etat._fondu);
    shader
      ..setImageSampler(0, nette)
      ..setImageSampler(1, floue)
      ..setImageSampler(2, cartes.height!)
      ..setImageSampler(3, cartes.clear!);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _PeintreEau old) => false;
}

/// Le rendu des téléphones modestes : buée floue, traces du doigt et
/// gouttes dessinées, sans shader.
class _PeintreEauSimple extends CustomPainter {
  _PeintreEauSimple({required this.etat, Listenable? repaint}) : super(repaint: repaint);

  final _VitreEmbueeState etat;

  @override
  void paint(Canvas canvas, Size size) {
    final floue = etat._floue;
    final sim = etat._sim;
    if (floue == null || sim == null) return;
    final fondu = etat._fondu;
    final sombre = OuroColors.isDark;
    final r = Offset.zero & size;

    canvas.saveLayer(r, Paint()..color = Color.fromRGBO(0, 0, 0, fondu));
    // La buée : le fond flou, voilé.
    final opaciteBuee = etat._buee;
    canvas.saveLayer(r, Paint()..color = Color.fromRGBO(0, 0, 0, opaciteBuee));
    canvas.drawImageRect(
      floue,
      Rect.fromLTWH(0, 0, floue.width.toDouble(), floue.height.toDouble()),
      r,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.drawRect(r, Paint()..color = sombre ? const Color(0x33939FAA) : const Color(0x55F0F3F7));
    // Le doigt retire la buée.
    canvas.drawPath(
      etat._traces,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = sim.settings.fingerRadius * 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();

    // Les gouttes.
    final corps = Paint()..color = sombre ? const Color(0x26FFFFFF) : const Color(0x33FFFFFF);
    final bord = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x40000000);
    final reflet = Paint()..color = const Color(0xCCFFFFFF);
    for (final d in sim.drops) {
      final c = Offset(d.x, d.y);
      final st = math.min(d.vy * 0.004, 0.35);
      final o = Rect.fromCenter(center: c, width: d.r * 2 * (1 - st * 0.4), height: d.r * 2 * (1 + st));
      canvas.drawOval(o, corps);
      canvas.drawOval(o, bord);
      canvas.drawCircle(c + Offset(d.r * 0.35, -d.r * 0.4), d.r * 0.18, reflet);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PeintreEauSimple old) => false;
}
