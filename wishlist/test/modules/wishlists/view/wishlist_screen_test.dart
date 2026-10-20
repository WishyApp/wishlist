import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_app_bar.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_floating_actions.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_stats_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishs_tab.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_display_provider.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wish_taken_by_user/wish_taken_by_user.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/providers/wishlist_theme_provider.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

class _MockUserCompletedWishRepository extends Mock
    implements UserCompletedWishRepository {}

void main() {
  CompletedWishWithDetails completedWish(Wish wish, int quantity) {
    return CompletedWishWithDetails(
      wish: wish,
      fromWishlistId: wish.wishlistId,
      fromWishlistName: fakeWishlist1.name,
      ownerPseudo: fakeCurrentUserProfile.pseudo,
      ownerId: fakeCurrentUserId,
      completedAt: fakeNow,
      quantity: quantity,
    );
  }

  Future<void> expectShareButtonVisibility({
    required WidgetTester tester,
    required String testName,
    required int wishlistId,
    required Wishlist wishlist,
    required bool shouldShowShareButton,
  }) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: wishlistId).location,
      overrides: wishlistScreenOverrides(
        wishlistId: wishlistId,
        wishlist: wishlist,
        wishes: fakeWishes,
        currentUserId: fakeCurrentUserId,
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));

    final shareFinder = find.byIcon(Icons.share);
    expect(
      shareFinder,
      shouldShowShareButton ? findsOneWidget : findsNothing,
      reason: testName,
    );
  }

  testAdaptiveWidgets('$WishlistScreen golden test with wishes',
      (tester, variant) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 2).location,
      windowConfig: variant,
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: fakeWishes,
      ),
    );

    // Pump suffisamment pour que les animations se terminent
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.expectGolden<WishlistScreen>(variant);
  });

  testAdaptiveWidgets('$WishlistScreen golden test when empty',
      (tester, variant) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 2).location,
      windowConfig: variant,
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: [],
      ),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<WishlistScreen>(variant, suffix: 'empty');
  });

  testAdaptiveWidgets('$WishlistScreen golden test with booked wishes',
      (tester, variant) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 2).location,
      windowConfig: variant,
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: fakeWishesWithBooked,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap sur l'onglet "booked" pour naviguer vers la page des réservations
    final bookedCard = find.byWidgetPredicate(
      (widget) =>
          widget is WishlistStatsCard &&
          widget.type == WishlistStatsCardType.booked,
    );

    await tester.tap(bookedCard);

    // Pump suffisamment pour que les animations se terminent
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.expectGolden<WishlistScreen>(variant, suffix: 'booked');
  });

  testWidgets(
    'should only exit selection mode when user does back system action',
    (tester) async {
      await tester.pumpRouterApp(
        WishlistRoute(wishlistId: 2).location,
        overrides: wishlistScreenOverrides(
          wishlistId: 2,
          wishlist: fakeWishlist2,
          wishes: fakeWishes,
          currentUserId: fakeCurrentUserId,
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Long-press sur un wish pour activer le mode sélection
      final wishTile = find.text('iPhone 15 Pro');
      expect(wishTile, findsOneWidget);
      await tester.longPress(wishTile);
      await tester.pumpAndSettle();

      // En mode sélection : affiche Supprimer
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byType(WishlistScreen), findsOneWidget);

      // Simuler l'action retour système
      // (déclenche PopScope, pas le bouton AppBar)
      final context = tester.element(find.byType(WishlistScreen));
      await Navigator.of(context).maybePop();
      await tester.pumpAndSettle();

      // On reste sur l'écran et le mode sélection est quitté : affiche Ajouter
      expect(find.byType(WishlistScreen), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsNothing);
    },
  );

  testWidgets(
    'extends the list container to the bottom edge of the screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);

      await tester.pumpRouterApp(
        WishlistRoute(wishlistId: 2).location,
        overrides: wishlistScreenOverrides(
          wishlistId: 2,
          wishlist: fakeWishlist2,
          wishes: fakeWishes,
          currentUserId: fakeCurrentUserId,
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      final listBottom = tester.getBottomLeft(find.byType(WishsTab).first).dy;
      expect(listBottom, tester.view.physicalSize.height);
    },
  );

  testWidgets(
    'should not display share button when wishlist is private',
    (tester) async {
      await expectShareButtonVisibility(
        tester: tester,
        testName: 'private wishlist should hide share button',
        wishlistId: 1,
        wishlist: fakeWishlist1,
        shouldShowShareButton: false,
      );
    },
  );

  testWidgets(
    'should display share button when wishlist is public',
    (tester) async {
      await expectShareButtonVisibility(
        tester: tester,
        testName: 'public wishlist should show share button',
        wishlistId: 2,
        wishlist: fakeWishlist2,
        shouldShowShareButton: true,
      );
    },
  );

  testWidgets(
    'keeps the owner actions while the session ends and the screen is leaving',
    (tester) async {
      final session = FakeAuthSession(userId: fakeCurrentUserId);
      addTearDown(session.close);
      await tester.pumpRouterApp(
        WishlistRoute(wishlistId: 2).location,
        overrides: [
          ...wishlistScreenOverrides(
            wishlistId: 2,
            wishlist: fakeWishlist2,
            wishes: fakeWishes,
            currentUserId: fakeCurrentUserId,
          ),
          supabaseClientProvider.overrideWithValue(session.client),
        ],
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byIcon(Icons.add), findsOneWidget);

      session.signOut();
      await tester.pumpAndSettle();

      // The owner floating actions stay for the frames before the
      // router redirects.
      expect(find.byIcon(Icons.add), findsOneWidget);
    },
  );

  testWidgets(
    'displays a message and leaves the screen when the wishlist is deleted',
    (tester) async {
      await tester.pumpRouterApp(
        WishlistRoute(wishlistId: 1).location,
        overrides: wishlistScreenOverrides(
          wishlistId: 1,
          isWishlistDeleted: true,
          currentUserId: fakeCurrentUserId,
        ),
      );

      // Pas de pumpAndSettle : il irait jusqu'à la fermeture du snackbar
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Cette wishlist a été supprimée'), findsOneWidget);
      expect(find.byType(WishlistScreen), findsNothing);

      // Laisse le snackbar se fermer avant la fin du test
      await tester.pumpAndSettle();
    },
  );

  testWidgets('hides a fully completed wish and updates the pending count',
      (tester) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 1).location,
      overrides: wishlistScreenOverrides(
        wishlistId: 1,
        wishlist: fakeWishlist1,
        wishes: fakeWishes,
        completedWishes: [completedWish(fakeWish1, 1)],
        currentUserId: fakeCurrentUserId,
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text(fakeWish1.name), findsNothing);
    expect(find.text(fakeWish2.name), findsOneWidget);

    final pendingStatsCard = tester.widget<WishlistStatsCard>(
      find.byWidgetPredicate(
        (widget) =>
            widget is WishlistStatsCard &&
            widget.type == WishlistStatsCardType.pending,
      ),
    );
    expect(pendingStatsCard.count, 1);
  });

  testWidgets('hides a fully completed wish from a friend', (tester) async {
    final friendWishlist = Wishlist(
      id: fakeWishlist1.id,
      createdAt: fakeWishlist1.createdAt,
      name: fakeWishlist1.name,
      idOwner: fakeFriendUserId1,
      color: fakeWishlist1.color,
      endDate: fakeWishlist1.endDate,
      canOwnerSeeTakenWish: fakeWishlist1.canOwnerSeeTakenWish,
      order: fakeWishlist1.order,
      updatedBy: fakeWishlist1.updatedBy,
      updatedAt: fakeWishlist1.updatedAt,
    );
    final friendWish = fakeWish1.copyWith(wishlistId: friendWishlist.id);

    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: friendWishlist.id).location,
      overrides: wishlistScreenOverrides(
        wishlistId: friendWishlist.id,
        wishlist: friendWishlist,
        wishes: [friendWish, fakeWish2],
        completedWishes: [completedWish(friendWish, 1)],
        currentUserId: fakeCurrentUserId,
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text(friendWish.name), findsNothing);
    expect(find.text(fakeWish2.name), findsOneWidget);
  });

  testWidgets('displays the remaining quantity for a partially completed wish',
      (tester) async {
    final wishWithQuantity = fakeWish1.copyWith(quantity: 3);

    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 1).location,
      overrides: wishlistScreenOverrides(
        wishlistId: 1,
        wishlist: fakeWishlist1,
        wishes: [wishWithQuantity],
        completedWishes: [completedWish(wishWithQuantity, 1)],
        currentUserId: fakeCurrentUserId,
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text(wishWithQuantity.name), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
  });

  testWidgets('adjusts the booked quantity after a partial completion',
      (tester) async {
    final wishWithBookings = fakeWishBooked.copyWith(
      quantity: 4,
      takenByUser: [fakeWishTakenByUser.copyWith(quantity: 3)].toIList(),
    );

    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 1).location,
      overrides: wishlistScreenOverrides(
        wishlistId: 1,
        wishlist: fakeWishlist1,
        wishes: [wishWithBookings],
        completedWishes: [completedWish(wishWithBookings, 1)],
        currentUserId: fakeCurrentUserId,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is WishlistStatsCard &&
            widget.type == WishlistStatsCardType.booked,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text(wishWithBookings.name), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
  });

  testWidgets('completes the selected wish with its default quantity',
      (tester) async {
    final repository = _MockUserCompletedWishRepository();
    when(
      () => repository.markAsCompleted(
        userId: any(named: 'userId'),
        wishId: any(named: 'wishId'),
        fromWishlistId: any(named: 'fromWishlistId'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 1).location,
      overrides: [
        ...wishlistScreenOverrides(
          wishlistId: 1,
          wishlist: fakeWishlist1,
          wishes: fakeWishes,
          currentUserId: fakeCurrentUserId,
        ),
        userCompletedWishRepositoryProvider.overrideWithValue(repository),
      ],
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.longPress(find.text(fakeWish1.name));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();

    verify(
      () => repository.markAsCompleted(
        userId: fakeCurrentUserId,
        wishId: fakeWish1.id,
        fromWishlistId: fakeWishlist1.id,
        quantity: 1,
      ),
    ).called(1);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('does not rebuild the screen root when typing in the search',
      (tester) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 2).location,
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: fakeWishes,
        currentUserId: fakeCurrentUserId,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // L'AppBar est recréée à chaque build de la racine : son identité change
    // si, et seulement si, la racine est reconstruite
    final appBarBefore = tester.widget<WishlistAppBar>(
      find.byType(WishlistAppBar),
    );

    await tester.enterText(find.byType(TextField), 'AirPods');
    await tester.pumpAndSettle();

    // La recherche est bien prise en compte par le body
    expect(find.text(fakeWish1.name), findsNothing);
    expect(find.text(fakeWish2.name), findsOneWidget);
    expect(
      identical(
        tester.widget<WishlistAppBar>(find.byType(WishlistAppBar)),
        appBarBefore,
      ),
      isTrue,
    );
  });

  testWidgets('updates the selection badge when a second wish is selected',
      (tester) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 2).location,
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: fakeWishes,
        currentUserId: fakeCurrentUserId,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    Finder badges(String count) => find.descendant(
          of: find.byType(WishlistFloatingActions),
          matching: find.text(count),
        );

    await tester.longPress(find.text(fakeWish1.name));
    await tester.pumpAndSettle();

    // Un badge par bouton d'action (compléter, déplacer, supprimer)
    expect(badges('1'), findsNWidgets(3));
    expect(badges('2'), findsNothing);

    await tester.tap(find.text(fakeWish2.name));
    await tester.pumpAndSettle();

    expect(badges('2'), findsNWidgets(3));
    expect(badges('1'), findsNothing);
  });

  test('derives pending quantities as quantity - max(booked, received)',
      () async {
    Wish wishWithId(
      int id, {
      required int quantity,
      required IList<WishTakenByUser> takenByUser,
    }) =>
        Wish(
          id: id,
          createdAt: fakeWish1.createdAt,
          name: 'wish $id',
          description: '',
          price: 10,
          linkUrl: '',
          quantity: quantity,
          wishlistId: fakeWishlist2.id,
          updatedBy: fakeCurrentUserId,
          updatedAt: fakeWish1.updatedAt,
          takenByUser: takenByUser,
        );

    final wishBooked1Received1 = wishWithId(
      101,
      quantity: 3,
      takenByUser: [fakeWishTakenByUser.copyWith(quantity: 1)].toIList(),
    );
    final wishBooked1Received2 = wishWithId(
      102,
      quantity: 3,
      takenByUser: [fakeWishTakenByUser.copyWith(quantity: 1)].toIList(),
    );
    final wishFullyReceived = wishWithId(
      103,
      quantity: 2,
      takenByUser: IList(),
    );
    final wishFullyBooked = wishWithId(
      104,
      quantity: 2,
      takenByUser: [fakeWishTakenByUser.copyWith(quantity: 2)].toIList(),
    );
    final container = ProviderContainer(
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: [
          wishBooked1Received1,
          wishBooked1Received2,
          wishFullyReceived,
          wishFullyBooked,
        ],
        completedWishes: [
          completedWish(wishBooked1Received1, 1),
          completedWish(wishBooked1Received2, 2),
          completedWish(wishFullyReceived, 2),
        ],
        currentUserId: fakeCurrentUserId,
      ),
    );
    addTearDown(container.dispose);
    container
      ..listen(wishlistScreenDisplayProvider(2), (_, __) {})
      ..listen(wishlistScreenNotifierProvider(2), (_, __) {});
    await pumpEventQueue();

    final display = container.read(wishlistScreenDisplayProvider(2));

    // Un wish entièrement reçu est exclu partout
    expect(display.all.map((w) => w.id), isNot(contains(103)));
    expect(display.booked.map((w) => w.id), isNot(contains(103)));
    // Quantité 3, réservé 1, reçu 1 -> en attente 2 ; reçu 2 -> en attente 1
    expect(display.pendingQuantityOverrides[101], 2);
    expect(display.pendingQuantityOverrides[102], 1);
    expect(display.available.map((w) => w.id), unorderedEquals([101, 102]));
    // Entièrement réservé : plus rien en attente
    expect(display.pendingQuantityOverrides[104], 0);
    // Réservé affiché = max(réservé - reçu, 0)
    expect(display.bookedQuantityOverrides[101], 0);
    expect(display.bookedQuantityOverrides[102], 0);
  });

  test('does not recompute the displayed wishs on selection change', () async {
    final container = ProviderContainer(
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: fakeWishes,
        currentUserId: fakeCurrentUserId,
      ),
    );
    addTearDown(container.dispose);

    // Maintient les providers en vie, comme le ferait l'écran
    container
      ..listen(wishlistScreenDisplayProvider(2), (_, __) {})
      ..listen(wishlistScreenNotifierProvider(2), (_, __) {});
    await pumpEventQueue();

    final display = container.read(wishlistScreenDisplayProvider(2));
    expect(display.all, hasLength(2));

    final notifier = container.read(wishlistScreenNotifierProvider(2).notifier);
    notifier
      ..enableSelectionMode(fakeWish1.id)
      ..toggleWishSelection(fakeWish2.id)
      ..onPageChanged(WishlistStatsCardType.booked.index)
      ..exitSelectionMode();

    // Un recalcul produirait de nouvelles collections, donc une autre instance
    expect(
      identical(container.read(wishlistScreenDisplayProvider(2)), display),
      isTrue,
    );

    // Contrôle : une vraie entrée (la recherche) relance bien le calcul
    notifier.searchController.text = 'AirPods';
    final searched = container.read(wishlistScreenDisplayProvider(2));
    expect(searched.all, hasLength(1));
    expect(identical(searched, display), isFalse);
  });

  test('does not keep the screen notifier alive once nobody listens', () async {
    final container = ProviderContainer(
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: fakeWishes,
        currentUserId: fakeCurrentUserId,
      ),
    );
    addTearDown(container.dispose);

    final displaySub = container.listen(
      wishlistScreenDisplayProvider(2),
      (_, __) {},
    );
    final notifierSub = container.listen(
      wishlistScreenNotifierProvider(2),
      (_, __) {},
    );
    await pumpEventQueue();
    container
        .read(wishlistScreenNotifierProvider(2).notifier)
        .enableSelectionMode(fakeWish1.id);

    displaySub.close();
    notifierSub.close();
    await pumpEventQueue();

    expect(container.exists(wishlistScreenDisplayProvider(2)), isFalse);
    expect(container.exists(wishlistScreenNotifierProvider(2)), isFalse);
  });

  testWidgets('writes the wishlist theme cache only when the theme changes',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(createMockSupabaseClient()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(wishlistScreenNotifierProvider(2), (_, __) {});
    addTearDown(sub.close);
    final notifier = container.read(wishlistScreenNotifierProvider(2).notifier);

    // StateController notifie à chaque écriture d'une autre instance
    var writes = 0;
    container.listen(wishlistThemeCacheProvider(2), (_, __) => writes++);

    notifier.cacheWishlistTheme(2, ThemeData.light());
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(writes, 1);

    // Un thème égal par valeur (mais autre instance) n'est pas réécrit
    notifier.cacheWishlistTheme(2, ThemeData.light());
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(writes, 1);

    notifier.cacheWishlistTheme(2, ThemeData.dark());
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(writes, 2);
  });
}
