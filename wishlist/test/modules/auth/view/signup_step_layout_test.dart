import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/modules/auth/view/birthday_step_screen.dart';
import 'package:wishlist/modules/auth/view/pseudo_screen.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

void main() {
  testWidgets('the signup steps have their main button at the same place',
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

    expect(pseudo.top, birthday.top);
    expect(pseudo.left, birthday.left);
    expect(pseudo.width, birthday.width);
  });
}
