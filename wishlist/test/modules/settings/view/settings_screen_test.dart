import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/widgets/avatar/editable_avatar.dart';

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

  testWidgets('offers to change the password of an email account',
      (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier mon mot de passe'), findsOneWidget);
  });

  testWidgets('hides the password line for a Google-only account',
      (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(authProviders: ['google']),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier mon mot de passe'), findsNothing);
  });

  testWidgets('leaves the profile lines to the edit profile page',
      (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(
        currentUserBirthday: const Birthday(month: 3, day: 12),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier mon pseudo'), findsNothing);
    expect(find.text('Pseudo'), findsNothing);
    expect(find.text('Mon anniversaire'), findsNothing);
    expect(find.text('Anniversaire'), findsNothing);
    expect(find.text('12 mars'), findsNothing);
    expect(find.text('MonPseudo'), findsNothing);
    expect(find.byType(EditableAvatar), findsNothing);
  });

  testWidgets('does not list the completed wishes', (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes wishs complétés'), findsNothing);
  });
}
