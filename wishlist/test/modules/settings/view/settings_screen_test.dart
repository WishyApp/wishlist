import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/widgets/avatar/editable_avatar.dart';
import 'package:wishlist/shared/widgets/settings_line.dart';

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
    expect(find.text('Connecté en tant que'), findsNothing);
  });

  testWidgets('shows the current user email as an information line',
      (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(currentUserEmail: 'me@x.fr'),
    );
    await tester.pumpAndSettle();

    final line = find.ancestor(
      of: find.text('me@x.fr'),
      matching: find.byType(SettingsLine),
    );
    expect(
      find.descendant(of: line, matching: find.text('Connecté en tant que')),
      findsOneWidget,
    );
    // Nothing to open: no arrow, no ripple
    expect(
      find.descendant(of: line, matching: find.byIcon(Icons.arrow_forward_ios)),
      findsNothing,
    );
    expect(
      find.descendant(of: line, matching: find.byType(InkWell)),
      findsNothing,
    );
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

  testWidgets('no longer holds the profile or the received wishes',
      (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier le profil'), findsNothing);
    expect(find.text('Mes wishs complétés'), findsNothing);
  });

  testWidgets('ends right above the home indicator', (tester) async {
    const inset = 34.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 500);
    addTearDown(tester.view.reset);

    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(bottom: inset),
          viewPadding: const EdgeInsets.only(bottom: inset),
        ),
        child: child!,
      ),
    );
    await tester.pumpAndSettle();

    final version = find.textContaining('v1.0.0');
    await tester.scrollUntilVisible(version, 100);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    // Clear of the home indicator and nothing more: no page padding stacked on
    // the bottom inset.
    expect(tester.getBottomLeft(version).dy, 500 - inset);
  });
}
