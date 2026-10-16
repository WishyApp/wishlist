import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/shared/infra/crash_reporting_preference.dart';
import 'package:wishlist/shared/navigation/routes.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

void main() {
  testAdaptiveWidgets('$SettingsScreen golden test', (tester, variant) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      windowConfig: variant,
      overrides: settingsScreenOverrides(),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<SettingsScreen>(variant);
  });

  group('crash reports toggle', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.pumpRouterApp(
        SettingsRoute().location,
        overrides: settingsScreenOverrides(),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
    }

    testWidgets('is on by default and persists the opt-out', (tester) async {
      await pumpSettings(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(CrashReportingPreference.enabledKey), isFalse);
    });

    testWidgets('toggles when tapping the row and warns when turned on',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Envoyer les rapports de plantage'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.text('Envoyer les rapports de plantage'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(
        find.text("Pris en compte au prochain lancement de l'app"),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('exposes a single toggle semantics node', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSettings(tester);

      expect(
        tester.getSemantics(find.text('Envoyer les rapports de plantage')),
        matchesSemantics(
          label: 'Envoyer les rapports de plantage',
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
          hint: 'Aide à corriger les bugs. Ni ton email ni ton pseudo ne sont '
              'envoyés.',
        ),
      );
      handle.dispose();
    });
  });
}
