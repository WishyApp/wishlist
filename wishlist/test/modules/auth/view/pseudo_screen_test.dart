import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/auth/view/pseudo_screen.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Profile(id: 'id', pseudo: 'pseudo'));
  });

  testAdaptiveWidgets('$PseudoScreen golden test', (tester, variant) async {
    await tester.pumpRouterApp(
      PseudoRoute().location,
      windowConfig: variant,
      overrides: pseudoScreenOverrides(),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<PseudoScreen>(variant);
  });

  group('on success', () {
    late MockUserService userService;

    setUp(() {
      userService = MockUserService();
      when(() => userService.createUserProfile(any())).thenAnswer((_) async {});
    });

    Future<void> submit(WidgetTester tester, {String? redirectTo}) async {
      String? reached;
      await tester.pumpRouterApp(
        PseudoRoute().location,
        overrides: [
          ...pseudoScreenOverrides(),
          userServiceProvider.overrideWithValue(userService),
        ],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Text('home-stub'),
            routes: [
              GoRoute(
                path: 'pseudo',
                builder: (_, __) => PseudoScreen(redirectTo: redirectTo),
              ),
              GoRoute(
                path: 'birthday',
                builder: (_, state) {
                  reached = state.uri.toString();
                  return const Text('birthday-stub');
                },
              ),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('birthday-stub'), findsOneWidget);
      expect(find.text('home-stub'), findsNothing);
      verify(() => userService.createUserProfile(any())).called(1);
      _reached = reached;
    }

    testWidgets('goes to the birthday step', (tester) async {
      await submit(tester);

      expect(_reached, '/birthday');
    });

    testWidgets('keeps redirectTo for the birthday step', (tester) async {
      await submit(tester, redirectTo: '/wishlist/1');

      expect(_reached, '/birthday?redirectTo=%2Fwishlist%2F1');
    });
  });
}

String? _reached;
