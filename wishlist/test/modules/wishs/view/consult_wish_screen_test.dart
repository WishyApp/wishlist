import 'dart:async';
import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
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

  group('receipts of the wishlist owner', () {
    final l10n = AppLocalizationsFr();
    final friendWishlist = Wishlist(
      id: 1,
      createdAt: fakeCreatedAt,
      name: 'Anniversaire',
      idOwner: fakeFriendUserId1,
      color: fakeColorBlue,
      endDate: DateTime(2024, 6, 15),
      canOwnerSeeTakenWish: true,
      order: 0,
      updatedBy: fakeFriendUserId1,
      updatedAt: fakeUpdatedAt,
    );

    CompletedWishWithDetails received(Wish wish, int quantity) =>
        CompletedWishWithDetails(
          wish: wish,
          fromWishlistId: wish.wishlistId,
          fromWishlistName: friendWishlist.name,
          ownerPseudo: 'Alice',
          ownerId: fakeFriendUserId1,
          completedAt: fakeCreatedAt,
          quantity: quantity,
        );

    Stream<IList<CompletedWishWithDetails>> failingReceipts() =>
        Stream.error(Exception('boom'));

    // The current user ('fake-current-user-id') is a guest of a friend.
    Future<void> pumpFriendWish(
      WidgetTester tester, {
      required Wish wish,
      required Stream<IList<CompletedWishWithDetails>> Function() receipts,
      WishQuantityDisplay quantityDisplay = WishQuantityDisplay.total,
    }) async {
      await tester.pumpApp(
        ConsultWishScreen(
          wishIds: [wish.id],
          initialIndex: 0,
          quantityDisplay: quantityDisplay,
        ),
        overrides: wishScreenOverrides(
          wishId: wish.id,
          wishlistId: wish.wishlistId,
          wish: wish,
          wishlist: friendWishlist,
          receipts: receipts,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpOwnWish(
      WidgetTester tester, {
      required Stream<IList<CompletedWishWithDetails>> Function() receipts,
    }) async {
      await tester.pumpApp(
        const ConsultWishScreen(wishIds: [1], initialIndex: 0),
        overrides: wishScreenOverrides(
          wishId: 1,
          wishlistId: 1,
          wish: fakeWish1,
          wishlist: fakeWishlist1,
          receipts: receipts,
        ),
      );
      await tester.pumpAndSettle();
    }

    final bookedWish = fakeWish1.copyWith(
      quantity: 2,
      takenByUser: [
        fakeWishTakenByUser.copyWith(
          wishId: fakeWish1.id,
          userId: fakeCurrentUserId,
        ),
      ].toIList(),
    );

    testWidgets('hides the give action while the receipts are loading',
        (tester) async {
      await pumpFriendWish(tester, wish: fakeWish1, receipts: Stream.empty);

      expect(find.text(fakeWish1.name), findsOneWidget);
      expect(find.text(l10n.iWantToGiveIt), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('hides the give action and the quantity when receipts fail',
        (tester) async {
      final wish = fakeWish1.copyWith(quantity: 3);
      await pumpFriendWish(
        tester,
        wish: wish,
        quantityDisplay: WishQuantityDisplay.pending,
        receipts: failingReceipts,
      );

      expect(find.text(wish.name), findsOneWidget);
      expect(find.text(l10n.iWantToGiveIt), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text('x3'), findsNothing);
    });

    testWidgets('keeps the cancel action but hides modify while loading',
        (tester) async {
      await pumpFriendWish(tester, wish: bookedWish, receipts: Stream.empty);

      expect(find.text(l10n.cancelBooking), findsWidgets);
      expect(find.text(l10n.modifyBooking), findsNothing);
    });

    testWidgets('keeps the cancel action but hides modify when receipts fail',
        (tester) async {
      await pumpFriendWish(
        tester,
        wish: bookedWish,
        receipts: failingReceipts,
      );

      expect(find.text(l10n.cancelBooking), findsWidgets);
      expect(find.text(l10n.modifyBooking), findsNothing);
    });

    testWidgets('shows cancel and modify once the receipts are known',
        (tester) async {
      await pumpFriendWish(
        tester,
        wish: bookedWish,
        receipts: () => Stream.value(const IListConst([])),
      );

      expect(find.text(l10n.cancelBooking), findsWidgets);
      expect(find.text(l10n.modifyBooking), findsWidgets);
    });

    testWidgets('hides the give action once the wish is received',
        (tester) async {
      final wish = fakeWish1.copyWith(quantity: 1);
      await pumpFriendWish(
        tester,
        wish: wish,
        receipts: () => Stream.value([received(wish, 1)].toIList()),
      );

      expect(find.text(wish.name), findsOneWidget);
      expect(find.text(l10n.iWantToGiveIt), findsNothing);
    });

    testWidgets(
        'shows the give action and the pending quantity when received partly',
        (tester) async {
      final wish = fakeWish1.copyWith(quantity: 3);
      await pumpFriendWish(
        tester,
        wish: wish,
        quantityDisplay: WishQuantityDisplay.pending,
        receipts: () => Stream.value([received(wish, 1)].toIList()),
      );

      expect(find.text(l10n.iWantToGiveIt), findsWidgets);
      expect(find.text('x2'), findsOneWidget);
    });

    testWidgets('shows the give action when nothing was received',
        (tester) async {
      await pumpFriendWish(
        tester,
        wish: fakeWish1,
        receipts: () => Stream.value(const IListConst([])),
      );

      expect(find.text(l10n.iWantToGiveIt), findsWidgets);
    });

    testWidgets('owner keeps edit but hides mark as completed while loading',
        (tester) async {
      await pumpOwnWish(tester, receipts: Stream.empty);

      expect(find.text('Modifier'), findsWidgets);
      expect(find.text(l10n.markWishAsCompleted), findsNothing);
    });

    testWidgets('owner keeps edit but hides mark as completed on error',
        (tester) async {
      await pumpOwnWish(tester, receipts: failingReceipts);

      expect(find.text(fakeWish1.name), findsOneWidget);
      expect(find.text('Modifier'), findsWidgets);
      expect(find.text(l10n.markWishAsCompleted), findsNothing);
    });

    testWidgets('owner sees mark as completed once the receipts are known',
        (tester) async {
      await pumpOwnWish(
        tester,
        receipts: () => Stream.value(const IListConst([])),
      );

      expect(find.text(l10n.markWishAsCompleted), findsWidgets);
    });

    testWidgets('hides the complete action on a wish that I received',
        (tester) async {
      await pumpOwnWish(
        tester,
        receipts: () => Stream.value(
          [received(fakeWish1, fakeWish1.quantity)].toIList(),
        ),
      );

      expect(find.text(l10n.markWishAsCompleted), findsNothing);
      expect(find.text('Modifier'), findsWidgets);
    });
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
