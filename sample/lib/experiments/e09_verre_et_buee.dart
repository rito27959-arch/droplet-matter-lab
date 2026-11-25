import 'package:droplet_glass/droplet_glass.dart';
import 'package:flutter/material.dart';

import '../app_compat/bouton_verre.dart';
import '../app_compat/compat.dart';
import '../app_compat/vitre_embuee.dart';
import '../core/lab_settings.dart';
import 'experiment.dart';

/// Expérience 09 — l'aperçu de deux pièces de l'application Droplet :
/// le bouton de verre (appui d'iOS 27) et la vitre embuée qui accueille au
/// retour après trois heures. Les noms et messages sont inventés.
class VerreEtBuee extends ExperimentLogic {
  @override
  int get number => 9;
  @override
  String get title => 'Verre et buée';
  @override
  String get summary =>
      'Les boutons de verre de l’app : ils gonflent sous le doigt et une lumière suit le doigt. « Revenir après 3 h » embue l’écran : essuyez-le.';
  @override
  String get shaderAsset => ShaderLibrary.waterGlass;

  final ValueNotifier<int> _retour = ValueNotifier(0);

  @override
  void writeUniforms(UniformWriter w, FrameContext f) {}

  @override
  Widget? body(BuildContext context, LabSettings settings) {
    OuroColors.isDark = settings.dark;
    return _Apercu(retour: _retour, sombre: settings.dark);
  }

  @override
  List<Widget> controls(BuildContext context, VoidCallback refresh, bool dark) => [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _retour.value++,
            child: const Text('Revenir après 3 h'),
          ),
        ),
      ];
}

class _Apercu extends StatelessWidget {
  const _Apercu({required this.retour, required this.sombre});

  final ValueNotifier<int> retour;
  final bool sombre;

  static const _discussions = [
    ('Amina', 'On se retrouve à la gare ?', '18:02', Color(0xFFE59A4C)),
    ('Groupe Famille', 'Jules : Les photos sont arrivées', '17:40', Color(0xFF5E8DE6)),
    ('Théo', 'Merci, bien reçu 👍', 'Hier', Color(0xFF59B37A)),
    ('Nadia', 'Vocal · 0:14', 'Hier', Color(0xFFB06AD9)),
    ('Club de lecture', 'Vous : Je prends le tome 2', 'Lundi', Color(0xFFD9606A)),
  ];

  @override
  Widget build(BuildContext context) {
    final fond = sombre ? Colors.black : const Color(0xFFF2F2F7);
    return Container(
      color: fond,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: VitreEmbuee(
              declencheur: retour,
              child: Container(
                color: fond,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 64, 12, 0),
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, color: OuroColors.label),
                          const Spacer(),
                          BoutonVerre.rond(
                            icone: Icons.add_rounded,
                            teinte: OuroColors.accentRempli,
                            diametre: 34,
                            semantique: 'Nouvelle discussion',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: Text('Discussions',
                          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: OuroColors.label)),
                    ),
                    for (final d in _discussions)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: d.$4,
                          child: Text(d.$1[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        title: Text(d.$1, style: TextStyle(color: OuroColors.label, fontWeight: FontWeight.w600)),
                        subtitle: Text(d.$2, style: TextStyle(color: OuroColors.secondaryLabel)),
                        trailing: Text(d.$3, style: TextStyle(color: OuroColors.secondaryLabel, fontSize: 13)),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text.rich(
                        TextSpan(children: [
                          WidgetSpan(child: Icon(Icons.lock_rounded, size: 13, color: OuroColors.secondaryLabel)),
                          const TextSpan(text: ' Vos messages personnels sont '),
                          TextSpan(
                              text: 'chiffrés de bout en bout',
                              style: TextStyle(color: OuroColors.accent, fontWeight: FontWeight.w600)),
                          const TextSpan(text: '.'),
                        ]),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: OuroColors.secondaryLabel),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: BoutonVerre.principal(libelle: 'Débloquer pour 1 000 F', onTap: () {}),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () {},
                        child: Text('Déjà payé ? Restaurer', style: TextStyle(color: OuroColors.accent)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
