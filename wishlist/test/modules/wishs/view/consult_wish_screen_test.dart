import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/theme/providers/wishlist_theme_provider.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

void main() {
  testAdaptiveWidgets('$ConsultWishScreen golden test',
      (tester, variant) async {
    await tester.pumpApp(
      const ConsultWishScreen(
        wishIds: [1],
        initialIndex: 0,
      ),
      windowConfig: variant,
      overrides: wishScreenOverrides(
        wishId: 1,
        wishlistId: 1,
        wish: fakeWish1,
        wishlist: fakeWishlist1,
      ),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<ConsultWishScreen>(variant);
  });

  testWidgets('shows the edit action when the current user owns the wishlist',
      (tester) async {
    await tester.pumpApp(
      const ConsultWishScreen(wishIds: [1], initialIndex: 0),
      overrides: wishScreenOverrides(
        wishId: 1,
        wishlistId: 1,
        wish: fakeWish1,
        wishlist: fakeWishlist1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsWidgets);
  });

  testWidgets('hides the edit action when another user owns the wishlist',
      (tester) async {
    await tester.pumpApp(
      const ConsultWishScreen(wishIds: [1], initialIndex: 0),
      overrides: wishScreenOverrides(
        wishId: 1,
        wishlistId: 1,
        wish: fakeWish1,
        wishlist: fakeWishlist1,
        currentUserId: 'someone-else',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsNothing);
  });

  testWidgets('hides the actions while the wishlist owner is loading',
      (tester) async {
    await tester.pumpApp(
      const ConsultWishScreen(wishIds: [1], initialIndex: 0),
      overrides: [
        supabaseClientOverride(),
        userServiceOverride(),
        watchWishByIdOverride(1, wish: fakeWish1),
        // Thème en cache : l'écran s'affiche sans attendre la wishlist.
        wishlistThemeCacheProvider(1).overrideWith((ref) => ThemeData()),
        watchWishlistByIdProvider(1)
            .overrideWith((ref) => const Stream.empty()),
      ],
    );
    await tester.pump();

    expect(find.text(fakeWish1.name), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
  });

  testWidgets('hides the actions when the wishlist fails to load',
      (tester) async {
    await tester.pumpApp(
      const ConsultWishScreen(wishIds: [1], initialIndex: 0),
      overrides: [
        supabaseClientOverride(),
        userServiceOverride(),
        watchWishByIdOverride(1, wish: fakeWish1),
        wishlistThemeCacheProvider(1).overrideWith((ref) => ThemeData()),
        watchWishlistByIdProvider(1)
            .overrideWith((ref) => Stream.error(Exception('boom'))),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text(fakeWish1.name), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.text('Modifier'), findsNothing);
  });
}
