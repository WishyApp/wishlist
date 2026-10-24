import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/modules/auth/view/birthday_step_screen.dart';
import 'package:wishlist/modules/auth/view/pseudo_screen.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/widgets/birthday_picker.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

void main() {
  testWidgets('the signup steps anchor their main button at the bottom',
      (tester) async {
    // iPhone 8
    tester.view
      ..physicalSize = const Size(375, 667)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final userService = MockUserService();

    Future<Rect> buttonRect(Widget screen) async {
      await tester.pumpRouterApp(
        '/',
        overrides: [
          ...pseudoScreenOverrides(),
          userServiceProvider.overrideWithValue(userService),
        ],
        routes: [GoRoute(path: '/', builder: (_, __) => screen)],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return tester.getRect(find.byType(PrimaryButton));
    }

    final pseudo = await buttonRect(const PseudoScreen());
    final birthday = await buttonRect(const BirthdayStepScreen());

    // 16 px of bottom padding under the button, on both steps
    expect(pseudo.bottom, 667 - 16);
    expect(birthday.bottom, 667 - 16);
  });

  testWidgets('the header sits at the top, the input right above the actions',
      (tester) async {
    // iPhone 13: room to spare between the two blocks
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final userService = MockUserService();

    Future<void> pump(Widget screen) async {
      await tester.pumpRouterApp(
        '/',
        overrides: [
          ...pseudoScreenOverrides(),
          userServiceProvider.overrideWithValue(userService),
        ],
        routes: [GoRoute(path: '/', builder: (_, __) => screen)],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pump(const PseudoScreen());
    expect(tester.getTopLeft(find.byType(SvgPicture)).dy, 32);
    expect(
      tester.getBottomLeft(find.byType(TextFormField)).dy + 16,
      tester.getTopLeft(find.byType(PrimaryButton)).dy,
    );

    await pump(const BirthdayStepScreen());
    expect(tester.getTopLeft(find.byType(SvgPicture)).dy, 32);
    expect(
      tester.getBottomLeft(find.byType(BirthdayPicker)).dy + 16,
      tester.getTopLeft(find.byType(TextButton)).dy,
    );
  });

  testWidgets('on a very short screen, the whole step scrolls without overflow',
      (tester) async {
    // Landscape phone with the keyboard open: 200 px left for the step.
    // Portrait is locked on Android only, iOS rotates.
    tester.view
      ..physicalSize = const Size(640, 360)
      ..devicePixelRatio = 1
      ..viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(tester.view.reset);

    final userService = MockUserService();

    for (final screen in [
      const PseudoScreen(),
      const BirthdayStepScreen(),
    ]) {
      await tester.pumpRouterApp(
        '/',
        overrides: [
          ...pseudoScreenOverrides(),
          userServiceProvider.overrideWithValue(userService),
        ],
        routes: [GoRoute(path: '/', builder: (_, __) => screen)],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The actions are part of the scrolled content: reachable by scrolling
      await tester.scrollUntilVisible(
        find.byType(PrimaryButton),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final button = tester.getRect(find.byType(PrimaryButton));
      expect(button.top, greaterThanOrEqualTo(0));
      expect(button.bottom, lessThanOrEqualTo(360 - 160));

      final input = find.byType(
        screen is PseudoScreen ? TextFormField : BirthdayPicker,
      );
      await tester.scrollUntilVisible(
        input,
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(input).top, greaterThanOrEqualTo(0));
    }
  });
}
