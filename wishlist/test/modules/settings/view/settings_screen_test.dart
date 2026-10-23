import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
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

  // Right after a sign-out the screen can be rebuilt once before the redirect:
  // no current user, so no email. Mounted directly, not behind the route's
  // session guard, so the screen itself stays tolerant.
  testWidgets('hides the email line without a signed-in user', (tester) async {
    await tester.pumpApp(
      const SettingsScreen(),
      overrides: settingsScreenOverrides(signedOut: true),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('test@example.com'), findsNothing);
  });

  testWidgets('shows the current user email', (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(currentUserEmail: 'me@x.fr'),
    );
    await tester.pumpAndSettle();

    expect(find.text('me@x.fr'), findsOneWidget);
  });
}
