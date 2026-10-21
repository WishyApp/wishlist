import 'dart:async';
import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
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

  group('when loading fails', () {
    final l10n = AppLocalizationsFr();
    final networkError = AppException(
      statusCode: 500,
      cause: const SocketException('Failed host lookup'),
    );

    testWidgets('explains the error, keeps the back button and retries',
        (tester) async {
      var loads = 0;

      await tester.pumpPushedScreen(
        const ConsultWishScreen(wishIds: [1], initialIndex: 0),
        overrides: [
          supabaseClientOverride(),
          userServiceOverride(),
          watchWishlistByIdOverride(1, wishlist: fakeWishlist1),
          watchWishByIdProvider(1).overrideWith((ref) {
            loads++;
            return loads == 1
                ? Stream.error(networkError)
                : Stream.value(fakeWish1);
          }),
        ],
      );

      expect(find.text(l10n.networkErrorTitle), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(loads, 2);
      expect(find.text(l10n.networkErrorTitle), findsNothing);
      expect(find.text(fakeWish1.name), findsOneWidget);
    });

    testWidgets('retries the wishlist that the theme depends on',
        (tester) async {
      var loads = 0;

      await tester.pumpPushedScreen(
        const ConsultWishScreen(wishIds: [1], initialIndex: 0),
        overrides: [
          supabaseClientOverride(),
          userServiceOverride(),
          watchWishByIdOverride(1, wish: fakeWish1),
          watchWishlistByIdProvider(1).overrideWith((ref) {
            loads++;
            return loads == 1
                ? Stream.error(networkError)
                : Stream.value(fakeWishlist1);
          }),
        ],
      );

      expect(find.text(l10n.networkErrorTitle), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(loads, 2);
      expect(find.text(fakeWish1.name), findsOneWidget);
    });

    testWidgets('shows the retry as loading while the failed source reloads',
        (tester) async {
      var loads = 0;
      final reload = StreamController<Wish>();
      addTearDown(reload.close);

      await tester.pumpPushedScreen(
        const ConsultWishScreen(wishIds: [1], initialIndex: 0),
        overrides: [
          supabaseClientOverride(),
          userServiceOverride(),
          watchWishlistByIdOverride(1, wishlist: fakeWishlist1),
          watchWishByIdProvider(1).overrideWith((ref) {
            loads++;
            return loads == 1 ? Stream.error(networkError) : reload.stream;
          }),
        ],
      );

      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).isLoading,
        isFalse,
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).isLoading,
        isTrue,
      );
    });

    testWidgets('shows a spinner and a way back on a first load, no retry',
        (tester) async {
      final hanging = StreamController<Wish>();
      addTearDown(hanging.close);

      await tester.pumpPushedScreen(
        const ConsultWishScreen(wishIds: [1], initialIndex: 0),
        overrides: [
          supabaseClientOverride(),
          userServiceOverride(),
          watchWishByIdProvider(1).overrideWith((ref) => hanging.stream),
        ],
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('says that an unavailable wish is gone, without retry',
        (tester) async {
      await tester.pumpPushedScreen(
        const ConsultWishScreen(wishIds: [1], initialIndex: 0),
        overrides: [
          supabaseClientOverride(),
          userServiceOverride(),
          watchWishByIdProvider(1).overrideWith(
            (ref) => Stream.error(
              AppException(
                statusCode: 500,
                cause: const PostgrestException(
                  message: 'no rows',
                  code: 'PGRST116',
                ),
              ),
            ),
          ),
        ],
      );

      expect(find.text(l10n.wishUnavailable), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);
    });
  });
}
