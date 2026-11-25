import 'package:flutter/material.dart';

import 'package:droplet_core/droplet_core.dart';
import '../core/lab_settings.dart';
import '../experiments/experiment.dart';
import '../experiments/registry.dart';
import 'package:droplet_glass/droplet_glass.dart';
import 'lab_theme.dart';

/// Accueil du laboratoire : les six expériences, la qualité, le thème.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.settings, required this.monitor});

  final LabSettings settings;
  final FrameMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final c = LabColors.of(settings.dark);
    final logics = [for (final f in experimentFactories) f()];
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            Text('Droplet Matter Lab', style: LabType.data(c.muted)),
            const SizedBox(height: 12),
            Text('Prismatic\nAether', style: LabType.display(c.ink, size: 52, flair: 85)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                'Six expériences pour mettre au point la matière visuelle de Droplet : '
                'la lumière, la géométrie, la matière et le mouvement.',
                style: LabType.body(c.muted),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<MatterQuality>(
                    showSelectedIcon: false,
                    segments: [
                      for (final q in MatterQuality.values)
                        ButtonSegment(value: q, label: Text(q.label, style: LabType.data(c.ink, size: 10))),
                    ],
                    selected: {settings.quality},
                    onSelectionChanged: (v) => settings.setQuality(v.first),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: settings.dark ? 'Thème clair' : 'Thème sombre',
                  onPressed: () => settings.setDark(!settings.dark),
                  icon: Icon(settings.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: c.ink),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final logic in logics) ...[
              _ExperimentRow(
                logic: logic,
                colors: c,
                available: ShaderLibrary.instance.failureOf(logic.shaderAsset) == null,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExperimentView(
                      logic: experimentFactories[logic.number - 1](),
                      settings: settings,
                      monitor: monitor,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: c.hairline),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExperimentRow extends StatelessWidget {
  const _ExperimentRow({required this.logic, required this.colors, required this.available, required this.onOpen});

  final ExperimentLogic logic;
  final LabColors colors;
  final bool available;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 40, child: Text(logic.number.toString().padLeft(2, '0'), style: LabType.data(colors.muted))),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(logic.title, style: LabType.display(colors.ink, size: 20, flair: 30)),
                  const SizedBox(height: 4),
                  Text(logic.summary, style: LabType.body(colors.muted, size: 13.5)),
                  if (!available) ...[
                    const SizedBox(height: 4),
                    Text('Shader indisponible sur cet appareil : rendu de repli', style: LabType.data(colors.muted, size: 11)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
