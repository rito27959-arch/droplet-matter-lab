import 'package:droplet_matter_lab/core/frame_monitor.dart';
import 'package:droplet_matter_lab/core/lab_settings.dart';
import 'package:droplet_matter_lab/ui/home_page.dart';
import 'package:droplet_matter_lab/ui/lab_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('l\'accueil liste les six expériences', (tester) async {
    final settings = LabSettings();
    await tester.pumpWidget(MaterialApp(
      theme: labThemeData(true),
      home: HomePage(settings: settings, monitor: FrameMonitor()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Surface prismatique'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Signature'), 200);
    expect(find.text('Signature'), findsOneWidget);
  });
}
