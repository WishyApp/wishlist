import 'dart:async';
import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository_provider.dart';
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
      Stream<IList<CompletedWishWithDetails>> Function()? currentUserReceipts,
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
          currentUserReceipts: currentUserReceipts,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpOwnWish(
      WidgetTester tester, {
      Stream<IList<CompletedWishWithDetails>> Function()? receipts,
      Wish? wish,
      Wishlist? wishlist,
      WishQuantityDisplay quantityDisplay = WishQuantityDisplay.total,
    }) async {
      await tester.pumpApp(
        ConsultWishScreen(
          wishIds: const [1],
          initialIndex: 0,
          quantityDisplay: quantityDisplay,
        ),
        overrides: wishScreenOverrides(
          wishId: 1,
          wishlistId: 1,
          wish: wish ?? fakeWish1,
          wishlist: wishlist ?? fakeWishlist1,
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

    testWidgets("reads the owner's receipts, not the current user's",
        (tester) async {
      final wish = fakeWish1.copyWith(quantity: 1);
      // I received this wish from someone else, my friend did not.
      await pumpFriendWish(
        tester,
        wish: wish,
        receipts: () => Stream.value(const IListConst([])),
        currentUserReceipts: () => Stream.value([received(wish, 1)].toIList()),
      );

      expect(find.text(l10n.iWantToGiveIt), findsWidgets);
    });

    testWidgets("ignores the current user's receipts for the pending quantity",
        (tester) async {
      final wish = fakeWish1.copyWith(quantity: 3);
      await pumpFriendWish(
        tester,
        wish: wish,
        quantityDisplay: WishQuantityDisplay.pending,
        receipts: () => Stream.value([received(wish, 1)].toIList()),
        currentUserReceipts: () => Stream.value([received(wish, 2)].toIList()),
      );

      expect(find.text('x2'), findsOneWidget);
    });

    group('owner who does not see the bookings', () {
      // The only booking they can still read is their own (legacy row).
      final ownBooked = fakeWish1.copyWith(
        quantity: 3,
        takenByUser: [
          fakeWishTakenByUser.copyWith(
            wishId: fakeWish1.id,
            userId: fakeCurrentUserId,
          ),
        ].toIList(),
      );
      final hiddenWishlist =
          fakeWishlist1.copyWith(canOwnerSeeTakenWish: false);

      testWidgets('ignores its own booking', (tester) async {
        await pumpOwnWish(
          tester,
          wish: ownBooked,
          wishlist: hiddenWishlist,
          quantityDisplay: WishQuantityDisplay.pending,
        );

        expect(find.text('x3'), findsOneWidget);
      });

      testWidgets('subtracts the bookings when it sees them', (tester) async {
        await pumpOwnWish(
          tester,
          wish: ownBooked,
          wishlist: fakeWishlist1,
          quantityDisplay: WishQuantityDisplay.pending,
        );

        expect(find.text('x2'), findsOneWidget);
      });
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

  group('completing the wish', () {
    final l10n = AppLocalizationsFr();

    /// The wish screen of the owner, pushed above a home page it pops back to
    Future<_MockUserCompletedWishRepository> pumpOwnWish(
      WidgetTester tester, {
      required Wish wish,
    }) async {
      registerFallbackValue(DateTime(2000));
      final repository = _MockUserCompletedWishRepository();
      when(
        () => repository.markAsCompleted(
          userId: any(named: 'userId'),
          wishId: any(named: 'wishId'),
          fromWishlistId: any(named: 'fromWishlistId'),
          quantity: any(named: 'quantity'),
          completedAt: any(named: 'completedAt'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpRouterApp(
        '/wish',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Text('home'),
            routes: [
              GoRoute(
                path: 'wish',
                builder: (context, state) => ConsultWishScreen(
                  wishIds: [wish.id],
                  initialIndex: 0,
                ),
              ),
            ],
          ),
        ],
        overrides: [
          ...wishScreenOverrides(
            wishId: wish.id,
            wishlistId: wish.wishlistId,
            wish: wish,
            wishlist: fakeWishlist1,
          ),
          userCompletedWishRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> tapDialogConfirm(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(PrimaryButton),
        ),
      );
    }

    testWidgets('asks the day, then the quantity of the named wish',
        (tester) async {
      final wish = fakeWish1.copyWith(quantity: 3);
      final repository = await pumpOwnWish(tester, wish: wish);

      await tester.tap(find.text(l10n.markWishAsCompleted).first);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.completionDateDialogExplanation(1)),
        findsOneWidget,
      );
      expect(find.text(l10n.continueButton), findsWidgets);
      await tapDialogConfirm(tester);
      await tester.pumpAndSettle();

      // The quantity dialog names the wish
      expect(find.text(l10n.selectQuantityToComplete), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(wish.name),
        ),
        findsOneWidget,
      );
      verifyNever(
        () => repository.markAsCompleted(
          userId: any(named: 'userId'),
          wishId: any(named: 'wishId'),
          fromWishlistId: any(named: 'fromWishlistId'),
          quantity: any(named: 'quantity'),
          completedAt: any(named: 'completedAt'),
        ),
      );

      final now = DateTime.now();
      await tapDialogConfirm(tester);
      // Not settled: the snackbar would be gone
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => repository.markAsCompleted(
          userId: fakeCurrentUserId,
          wishId: wish.id,
          fromWishlistId: wish.wishlistId,
          quantity: 1,
          completedAt: DateTime(now.year, now.month, now.day),
        ),
      ).called(1);
      expect(find.text(l10n.wishesCompletedSnackBar(1)), findsOneWidget);
      expect(find.text('home'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('completes a single wish from the day dialog', (tester) async {
      final repository = await pumpOwnWish(tester, wish: fakeWish1);

      await tester.tap(find.text(l10n.markWishAsCompleted).first);
      await tester.pumpAndSettle();
      await tapDialogConfirm(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => repository.markAsCompleted(
          userId: any(named: 'userId'),
          wishId: fakeWish1.id,
          fromWishlistId: any(named: 'fromWishlistId'),
          quantity: 1,
          completedAt: any(named: 'completedAt'),
        ),
      ).called(1);
      expect(find.text(l10n.selectQuantityToComplete), findsNothing);
      expect(find.text(l10n.wishesCompletedSnackBar(1)), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}

class _MockUserCompletedWishRepository extends Mock
    implements UserCompletedWishRepository {}
