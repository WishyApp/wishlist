import 'dart:async';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/models/birthday.dart';
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

  testWidgets('shows the birthday of the current user', (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(
        currentUserBirthday: const Birthday(month: 3, day: 12),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mon anniversaire'), findsOneWidget);
    expect(find.text('12 mars'), findsOneWidget);
    expect(find.text('Non renseigné'), findsNothing);
  });

  testWidgets('shows that the birthday is not set', (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: settingsScreenOverrides(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Non renseigné'), findsOneWidget);
  });

  testWidgets('shows a dash when the birthday fails to load', (tester) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: [
        ...settingsScreenOverrides(overrideBirthday: false),
        currentUserBirthdayProvider.overrideWith(
          (ref) async => throw AppException(statusCode: 500, message: 'boom'),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Non renseigné'), findsNothing);
  });

  testWidgets('shows no value while the birthday loads', (tester) async {
    final completer = Completer<Birthday?>();
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: [
        ...settingsScreenOverrides(overrideBirthday: false),
        currentUserBirthdayProvider.overrideWith((ref) => completer.future),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNothing);
    expect(find.text('Non renseigné'), findsNothing);
  });
}
