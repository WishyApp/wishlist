import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen.dart';
import 'package:wishlist/shared/navigation/routes.dart';

// ignore: avoid_implementing_value_types
class MockGoRouterState extends Mock implements GoRouterState {}

void main() {
  group('WishlistRoute received-on', () {
    test('is not in the location by default', () {
      expect(WishlistRoute(wishlistId: 3).location, '/wishlist/3');
    });

    test('is a query parameter of the location', () {
      expect(
        WishlistRoute(wishlistId: 3, receivedOn: '2026-12-25').location,
        '/wishlist/3?received-on=2026-12-25',
      );
    });

    Future<WishlistScreen> buildScreen(
      WidgetTester tester,
      WishlistRoute route,
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
      return built as WishlistScreen;
    }

    testWidgets('gives the parsed day to the screen', (tester) async {
      final screen = await buildScreen(
        tester,
        WishlistRoute(wishlistId: 3, receivedOn: '2026-12-25'),
      );

      expect(screen.receivedOn, DateTime(2026, 12, 25));
    });

    testWidgets('ignores a mangled value', (tester) async {
      final screen = await buildScreen(
        tester,
        WishlistRoute(wishlistId: 3, receivedOn: 'noel'),
      );

      expect(screen.receivedOn, isNull);
    });

    testWidgets('has no day without the parameter', (tester) async {
      final screen = await buildScreen(tester, WishlistRoute(wishlistId: 3));

      expect(screen.receivedOn, isNull);
    });
  });
}
