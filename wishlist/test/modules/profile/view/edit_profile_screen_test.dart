import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/profile/view/edit_profile_screen.dart';
import 'package:wishlist/modules/settings/change_birthday/view/change_birthday_screen.dart';
import 'package:wishlist/modules/settings/change_pseudo/view/change_pseudo_screen.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/navigation/routes.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

void main() {
  testAdaptiveWidgets('$EditProfileScreen golden test',
      (tester, variant) async {
    await tester.pumpRouterApp(
      EditProfileRoute().location,
      windowConfig: variant,
      overrides: settingsScreenOverrides(
        currentUserBirthday: const Birthday(month: 3, day: 12),
      ),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<EditProfileScreen>(variant);
  });

  testWidgets('shows the pseudo and the birthday of the current user',
      (tester) async {
    await tester.pumpRouterApp(
      EditProfileRoute().location,
      overrides: settingsScreenOverrides(
        currentUserBirthday: const Birthday(month: 3, day: 12),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pseudo'), findsOneWidget);
    expect(find.text('MonPseudo'), findsOneWidget);
    expect(find.text('Anniversaire'), findsOneWidget);
    expect(find.text('12 mars'), findsOneWidget);
    expect(find.text('Non renseigné'), findsNothing);
  });

  testWidgets('shows that the birthday is not set', (tester) async {
    await tester.pumpRouterApp(
      EditProfileRoute().location,
      overrides: settingsScreenOverrides(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Non renseigné'), findsOneWidget);
  });

  testWidgets('opens the pseudo screen from the pseudo line', (tester) async {
    await tester.pumpRouterApp(
      EditProfileRoute().location,
      overrides: [
        ...settingsScreenOverrides(),
        ...changePseudoScreenOverrides(),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pseudo'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePseudoScreen), findsOneWidget);
  });

  testWidgets('opens the birthday screen from the birthday line',
      (tester) async {
    await tester.pumpRouterApp(
      EditProfileRoute().location,
      overrides: settingsScreenOverrides(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anniversaire'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangeBirthdayScreen), findsOneWidget);
  });
}
