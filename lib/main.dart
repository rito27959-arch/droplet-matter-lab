import 'package:flutter/material.dart';

import 'core/frame_monitor.dart';
import 'core/lab_settings.dart';
import 'core/quality.dart';
import 'experiments/common_logic.dart';
import 'experiments/experiment.dart';
import 'experiments/registry.dart';
import 'rendering/shader_library.dart';
import 'ui/home_page.dart';
import 'ui/lab_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sur le web, l'adresse peut ouvrir une expérience précise dans un état figé,
  // pour des captures reproductibles : ?e=4&theme=dark&q=ultra&t=12&cycle=3.3
  final params = Uri.base.queryParameters;
  final t = double.tryParse(params['t'] ?? '');
  CaptureParams.cycle = double.tryParse(params['cycle'] ?? '');
  final settings = LabSettings(
    quality: MatterQuality.fromName(params['q']),
    dark: params['theme'] != 'light',
    frozenTime: t,
    adaptiveQuality: t == null,
    showFrameStats: t == null,
  );
  final experiment = int.tryParse(params['e'] ?? '');

  await ShaderLibrary.instance.warmUp();
  runApp(LabApp(settings: settings, initialExperiment: experiment));
}

class LabApp extends StatefulWidget {
  const LabApp({super.key, required this.settings, this.initialExperiment});

  final LabSettings settings;
  final int? initialExperiment;

  @override
  State<LabApp> createState() => _LabAppState();
}

class _LabAppState extends State<LabApp> {
  final _monitor = FrameMonitor();

  @override
  void initState() {
    super.initState();
    _monitor.attach();
    widget.settings.addListener(_onSettings);
  }

  void _onSettings() => setState(() {});

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final index = widget.initialExperiment;
    final capture = s.frozenTime != null;
    return MaterialApp(
      title: 'Droplet Matter Lab',
      debugShowCheckedModeBanner: false,
      theme: labThemeData(s.dark),
      home: index != null && index >= 1 && index <= experimentFactories.length
          ? ExperimentView(
              logic: experimentFactories[index - 1](),
              settings: s,
              monitor: _monitor,
              capture: capture,
            )
          : HomePage(settings: s, monitor: _monitor),
    );
  }
}
