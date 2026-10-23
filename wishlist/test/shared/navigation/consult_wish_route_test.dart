import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/navigation/routes.dart';

// build() n'utilise pas l'état : un mock suffit.
// ignore: avoid_implementing_value_types
class MockGoRouterState extends Mock implements GoRouterState {}

void main() {
  group('ConsultWishRoute.effectiveWishIds', () {
    test('keeps the list when it contains the wish id', () {
      final route = ConsultWishRoute(1, 2, wishIds: const [1, 2, 3]);

      expect(route.effectiveWishIds, [1, 2, 3]);
    });

    test('falls back to [wishId] for a deep link without wish-ids', () {
      final route = ConsultWishRoute(1, 2, wishIds: const []);

      expect(route.effectiveWishIds, [2]);
    });

    test('falls back to [wishId] when the list does not contain it', () {
      final route = ConsultWishRoute(1, 2, wishIds: const [5, 6]);

      expect(route.effectiveWishIds, [2]);
    });

    test('is not driven by is-my-wishlist in the location', () {
      final route = ConsultWishRoute(1, 2, wishIds: const []);

      expect(route.location, isNot(contains('is-my-wishlist')));
    });
  });

  group('ConsultWishRoute.buildScreen', () {
    Future<ConsultWishScreen> buildScreen(
      WidgetTester tester,
      ConsultWishRoute route,
    ) async {
      late Widget built;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            built = route.buildScreen(context, MockGoRouterState());
            return const SizedBox.shrink();
          },
        ),
      );
      return built as ConsultWishScreen;
    }

    testWidgets('does not crash for a deep link without wish-ids',
        (tester) async {
      // Reproduit le crash : wish-ids absent donne une liste vide, et
      // indexOf(...).clamp(0, -1) levait une ArgumentError dans build.
      final screen =
          await buildScreen(tester, ConsultWishRoute(1, 2, wishIds: const []));

      expect(screen.wishIds, [2]);
      expect(screen.initialIndex, 0);
    });

    testWidgets('opens the page of the wish in the list', (tester) async {
      final screen = await buildScreen(
        tester,
        ConsultWishRoute(1, 3, wishIds: const [1, 2, 3]),
      );

      expect(screen.wishIds, [1, 2, 3]);
      expect(screen.initialIndex, 2);
    });
  });
}
