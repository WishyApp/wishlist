import 'dart:async';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/profile/view/edit_profile_screen.dart';
import 'package:wishlist/modules/settings/change_birthday/view/change_birthday_screen.dart';
import 'package:wishlist/modules/settings/change_pseudo/view/change_pseudo_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
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

  testWidgets('shows a dash when the birthday fails to load', (tester) async {
    await tester.pumpRouterApp(
      EditProfileRoute().location,
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

  testWidgets('shows no birthday value while it loads', (tester) async {
    final completer = Completer<Birthday?>();
    await tester.pumpRouterApp(
      EditProfileRoute().location,
      overrides: [
        ...settingsScreenOverrides(overrideBirthday: false),
        currentUserBirthdayProvider.overrideWith((ref) => completer.future),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNothing);
    expect(find.text('Non renseigné'), findsNothing);
  });

  testWidgets('shows a dash when the profile fails to load', (tester) async {
    await tester.pumpRouterApp(
      EditProfileRoute().location,
      overrides: [
        ...settingsScreenOverrides(),
        watchCurrentUserProfileProvider.overrideWith(
          (ref) => Stream.error(
            AppException(statusCode: 500, message: 'boom'),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('MonPseudo'), findsNothing);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('goes back to the profile from a deep link to the birthday',
      (tester) async {
    await tester.pumpRouterApp(
      ChangeBirthdayRoute().location,
      overrides: settingsScreenOverrides(),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChangeBirthdayScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(ChangeBirthdayScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('goes back to the profile from a deep link to the pseudo',
      (tester) async {
    await tester.pumpRouterApp(
      ChangePseudoRoute().location,
      overrides: [
        ...settingsScreenOverrides(),
        ...changePseudoScreenOverrides(),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChangePseudoScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(ChangePseudoScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('keeps the profile routes under /profile', (tester) async {
    expect(ChangePseudoRoute().location, '/profile/change-pseudo');
    expect(ChangeBirthdayRoute().location, '/profile/change-birthday');
  });

  testWidgets('says what friends and list sharers can see', (tester) async {
    await tester.pumpRouterApp(
      EditProfileRoute().location,
      overrides: settingsScreenOverrides(),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Seuls tes amis voient ton anniversaire. Ton pseudo et ta photo sont '
        'visibles par tous.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ends right above the home indicator', (tester) async {
    const inset = 34.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 300);
    addTearDown(tester.view.reset);

    await tester.pumpRouterApp(
      EditProfileRoute().location,
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

    final privacyNote = find.text(AppLocalizationsFr().editProfilePrivacy);
    await tester.scrollUntilVisible(privacyNote, 100);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    // Clear of the home indicator and nothing more: no page padding stacked on
    // the bottom inset.
    expect(tester.getBottomLeft(privacyNote).dy, 300 - inset);
  });
}
