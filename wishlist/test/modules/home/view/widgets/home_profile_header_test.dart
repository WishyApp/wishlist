import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/modules/home/view/widgets/home_profile_header.dart';
import 'package:wishlist/modules/profile/view/edit_profile_screen.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/widgets/avatar/app_avatar.dart';

import '../../../../fixtures/fake_providers.dart';
import '../../../../pump_app.dart';

void main() {
  Future<void> pumpHeader(WidgetTester tester) async {
    await tester.pumpRouterApp(
      '/header',
      routes: [
        GoRoute(
          path: '/header',
          builder: (context, state) =>
              const Scaffold(body: SafeArea(child: HomeProfileHeader())),
        ),
        ...$appRoutes,
      ],
      overrides: settingsScreenOverrides(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the pseudo of the current user', (tester) async {
    await pumpHeader(tester);

    expect(find.text('MonPseudo'), findsOneWidget);
    expect(find.text('Modifier le profil'), findsOneWidget);
  });

  testWidgets('opens the edit profile page from the photo', (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byType(AppAvatar));
    await tester.pumpAndSettle();

    expect(
      find.byType(EditProfileScreen, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('opens the edit profile page from the button', (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.text('Modifier le profil'));
    await tester.pumpAndSettle();

    expect(
      find.byType(EditProfileScreen, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('opens the settings from the cog', (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('a tap in the empty space next to the button does nothing',
      (tester) async {
    await pumpHeader(tester);

    final button = tester.getRect(find.text('Modifier le profil'));
    // Right of the button, left of the cog, on the button's line
    await tester.tapAt(Offset(button.right + 80, button.center.dy));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
  });

  testWidgets('keeps the size of the pill with a 44 px tap area',
      (tester) async {
    await pumpHeader(tester);

    final pill = tester.getRect(find.byKey(editProfilePillKey));
    final tapArea = tester.getRect(
      find
          .ancestor(
            of: find.byKey(editProfilePillKey),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    // The visible pill is as before (about 30 px), only the tap area is taller
    expect(pill.height, inInclusiveRange(28, 34));
    expect(tapArea.height, greaterThanOrEqualTo(44));
    // As wide as the pill
    expect(tapArea.width, pill.width);
  });

  testWidgets(
      'a tap just above or below the pill, in its band, opens the '
      'profile', (tester) async {
    await pumpHeader(tester);
    final pill = tester.getRect(find.byKey(editProfilePillKey));

    await tester.tapAt(Offset(pill.center.dx, pill.top - 5));
    await tester.pumpAndSettle();
    expect(
      find.byType(EditProfileScreen, skipOffstage: false),
      findsOneWidget,
    );

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsNothing);

    await tester.tapAt(Offset(pill.center.dx, pill.bottom + 5));
    await tester.pumpAndSettle();
    expect(
      find.byType(EditProfileScreen, skipOffstage: false),
      findsOneWidget,
    );
  });
}
