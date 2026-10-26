import 'dart:async';
import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wish_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_app_bar.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_selection_action_bar.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_selection_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_stats_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishs_tab.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_display_provider.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wish_taken_by_user/wish_taken_by_user.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/page_layout_empty/page_layout_empty_content.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/providers/wishlist_theme_provider.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/wishlist_illustration_extension.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

class _MockUserCompletedWishRepository extends Mock
    implements UserCompletedWishRepository {}

/// Mounts the wishlist screen of its owner through [mount] with a controllable
/// session, then ends the session and settles.
Future<void> pumpSignedInWishlistThenSignOut(
  WidgetTester tester, {
  required Future<void> Function(List<Override> overrides) mount,
}) async {
  final session = FakeAuthSession(userId: fakeCurrentUserId);
  addTearDown(session.close);
  await mount([
    ...wishlistScreenOverrides(
      wishlistId: 2,
      wishlist: fakeWishlist2,
      wishes: fakeWishes,
      currentUserId: fakeCurrentUserId,
    ),
    supabaseClientProvider.overrideWithValue(session.client),
  ]);
  await tester.pumpAndSettle(const Duration(seconds: 1));
  expect(find.byIcon(Icons.add), findsOneWidget);

  session.signOut();
  await tester.pumpAndSettle();
}

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

  testAdaptiveWidgets('$WishlistScreen golden test in selection mode',
      (tester, variant) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 2).location,
      windowConfig: variant,
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        // Le jaune, la couleur la plus claire, que la carte doit foncer
        wishlist: fakeWishlist2.copyWith(
          color: AppColors.getHexValue(AppColors.yellow),
        ),
        wishes: fakeWishes,
        currentUserId: fakeCurrentUserId,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.longPress(find.text(fakeWish1.name));
    await tester.pumpAndSettle();

    await tester.expectGolden<WishlistScreen>(variant, suffix: 'selection');
  });

  testWidgets('shows the per-wishlist illustration when there is no wish',
      (tester) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 2).location,
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: [],
      ),
    );
    await tester.pumpAndSettle();

    // Restreint à l'onglet affiché : l'onglet Réservés (réservations masquées)
    // affiche la même scène s'il est construit.
    expect(
      find.descendant(
        of: find.byType(WishsTab).first,
        matching: find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  fakeWishlist2.noWishIllustration,
        ),
      ),
      findsOneWidget,
    );
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
    'builds nothing once the session ends, until the router redirects',
    (tester) async {
      await pumpSignedInWishlistThenSignOut(
        tester,
        mount: (overrides) => tester.pumpRouterApp(
          WishlistRoute(wishlistId: 2).location,
          overrides: overrides,
        ),
      );

      // The session guard replaces the screen with an empty page for the
      // frames before the router redirects (no redirect in this test).
      expect(tester.takeException(), isNull);
      expect(find.byType(WishlistScreen), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    },
  );

  testWidgets(
    'keeps the owner actions while the session ends and the screen is leaving '
    '(F015), without the route guard',
    (tester) async {
      // Mounted directly: not behind SessionGuard, so this covers the screen
      // itself should the guard ever go away.
      await pumpSignedInWishlistThenSignOut(
        tester,
        mount: (overrides) => tester.pumpApp(
          const WishlistScreen(wishlistId: 2),
          overrides: overrides,
        ),
      );

      // The owner floating actions stay for the frames before the
      // router redirects.
      expect(tester.takeException(), isNull);
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

  group('in selection mode', () {
    final l10n = AppLocalizationsFr();

    Future<void> pumpOwnerWishlist(
      WidgetTester tester, {
      List<Wish>? wishes,
      Wishlist? wishlist,
    }) async {
      await tester.pumpRouterApp(
        WishlistRoute(wishlistId: 2).location,
        overrides: wishlistScreenOverrides(
          wishlistId: 2,
          wishlist: wishlist ?? fakeWishlist2,
          wishes: wishes ?? fakeWishes,
          currentUserId: fakeCurrentUserId,
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    Finder inSelectionCard(Finder matching) => find.descendant(
          of: find.byType(WishlistSelectionCard),
          matching: matching,
        );

    Wish wishNamed(int id, String name) => Wish(
          id: id,
          createdAt: fakeCreatedAt,
          name: name,
          description: '',
          price: 10,
          quantity: 1,
          wishlistId: fakeWishlist2.id,
          updatedBy: fakeCurrentUserId,
          updatedAt: fakeUpdatedAt,
        );

    TextButton selectAllButton(WidgetTester tester) => tester.widget(
          find.ancestor(
            of: find.text(l10n.wishlistSelectAll),
            matching: find.byType(TextButton),
          ),
        );

    int selectedCount(WidgetTester tester) => tester
        .widget<WishlistSelectionCard>(find.byType(WishlistSelectionCard))
        .selectedCount;

    testWidgets('shows the count once, in the selection card', (tester) async {
      // 3 wishs: the stats show other numbers than the selected count
      await pumpOwnerWishlist(
        tester,
        wishes: [for (var id = 1; id <= 3; id++) wishNamed(id, 'Wish $id')],
      );

      await tester.longPress(find.text('Wish 1'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(inSelectionCard(find.text('1')), findsOneWidget);
      expect(
        inSelectionCard(find.text('sélectionné')),
        findsOneWidget,
      );
      expect(find.text(l10n.wishlistSelectionComplete), findsOneWidget);
      expect(find.text(l10n.wishlistSelectionMove), findsOneWidget);
      expect(find.text(l10n.wishlistSelectionDelete), findsOneWidget);

      await tester.tap(find.text('Wish 2'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(inSelectionCard(find.text('2')), findsOneWidget);
      expect(
        inSelectionCard(find.text('sélectionnés')),
        findsOneWidget,
      );
    });

    testWidgets('keeps the empty state clear of the action bar',
        (tester) async {
      await pumpOwnerWishlist(tester);

      await tester.longPress(find.text(fakeWish1.name));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Wulfgar');
      await tester.pumpAndSettle();

      // Adding is hidden in selection mode, like the "+" button
      expect(find.text(l10n.wishlistAddWish), findsNothing);
      final emptyContent = find
          .descendant(
            of: find.byType(WishsTab).first,
            matching: find.byType(PageLayoutEmptyContent),
          )
          .first;
      expect(
        tester.getBottomLeft(emptyContent).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(WishlistSelectionActionBar)).dy,
        ),
      );
    });

    testWidgets('ignores taps on the card and the bar while they leave',
        (tester) async {
      await pumpOwnerWishlist(tester);

      await tester.longPress(find.text(fakeWish1.name));
      await tester.pumpAndSettle();
      final selectAll = tester.getCenter(find.text(l10n.wishlistSelectAll));
      final delete = tester.getCenter(find.text(l10n.wishlistSelectionDelete));

      await tester.tap(find.byTooltip(l10n.wishlistExitSelection));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(delete);
      await tester.tapAt(selectAll);
      await tester.pumpAndSettle();

      expect(find.text(l10n.deleteSelectedWishes), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WishlistScreen)),
      );
      expect(
        container.read(wishlistScreenNotifierProvider(2)).isSelectionMode,
        isFalse,
      );
    });

    testWidgets('does not move the keyboard focus to the hidden stats',
        (tester) async {
      await pumpOwnerWishlist(tester);

      await tester.longPress(find.text(fakeWish1.name));
      await tester.pumpAndSettle();

      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<WishlistStatsCard>(),
          isNull,
        );
      }
    });

    testWidgets('announces the count to screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOwnerWishlist(tester);

      await tester.longPress(find.text(fakeWish1.name));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          l10n.wishlistSelectionCount(1),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            l10n.wishlistSelectionCount(1),
          ),
        ),
        isSemantics(isLiveRegion: true),
      );
      expect(find.byTooltip(l10n.wishlistExitSelection), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('keeps the selection through a search', (tester) async {
      await pumpOwnerWishlist(tester);

      await tester.longPress(find.text(fakeWish1.name));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'AirPods');
      await tester.pumpAndSettle();
      expect(find.text(fakeWish1.name), findsNothing);
      expect(selectedCount(tester), 1);

      await tester.tap(find.text(fakeWish2.name));
      await tester.pumpAndSettle();
      expect(selectedCount(tester), 2);

      // The wish hidden by the search is still selected
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(selectedCount(tester), 2);
    });

    testWidgets('selects all the wishes matching the search', (tester) async {
      final otherAirPods = wishNamed(10, 'AirPods Max');
      await pumpOwnerWishlist(
        tester,
        wishes: [...fakeWishes, otherAirPods],
      );

      await tester.longPress(find.text(fakeWish2.name));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'AirPods');
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.wishlistSelectAll));
      await tester.pumpAndSettle();

      // Only the 2 AirPods are added: nothing left to add among the results
      expect(selectedCount(tester), 2);
      expect(selectAllButton(tester).enabled, isFalse);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(selectedCount(tester), 2);
      expect(selectAllButton(tester).enabled, isTrue);

      await tester.tap(find.text(l10n.wishlistSelectAll));
      await tester.pumpAndSettle();
      expect(selectedCount(tester), 3);
      expect(selectAllButton(tester).enabled, isFalse);
    });

    testWidgets('disables select all for a search without result',
        (tester) async {
      await pumpOwnerWishlist(tester);

      await tester.longPress(find.text(fakeWish1.name));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Wulfgar');
      await tester.pumpAndSettle();

      expect(selectAllButton(tester).enabled, isFalse);
    });

    testWidgets('exits and clears the selection with the close button',
        (tester) async {
      await pumpOwnerWishlist(tester);

      await tester.longPress(find.text(fakeWish1.name));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.wishlistExitSelection));
      await tester.pumpAndSettle();

      expect(find.byType(WishlistSelectionCard), findsNothing);
      expect(find.byType(WishlistSelectionActionBar), findsNothing);
      expect(find.byType(WishlistStatsCard).hitTestable(), findsNWidgets(2));
      expect(find.byIcon(Icons.add), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(WishlistScreen)),
      );
      expect(
        container.read(wishlistScreenNotifierProvider(2)).selectedWishIds,
        isEmpty,
      );
    });

    testWidgets('keeps the count readable on a light wishlist color',
        (tester) async {
      await pumpOwnerWishlist(
        tester,
        wishlist: fakeWishlist2.copyWith(
          color: AppColors.getHexValue(AppColors.yellow),
        ),
      );

      await tester.longPress(find.text(fakeWish1.name));
      await tester.pumpAndSettle();

      final card = tester.widget<Container>(
        inSelectionCard(find.byType(Container)).first,
      );
      final background = (card.decoration! as BoxDecoration).color!;
      expect(
        AppColors.contrastRatio(background, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('keeps the last wish above the bar with a large text',
        (tester) async {
      // Wide enough for the stats cards, which overflow at this scale below
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpOwnerWishlist(
        tester,
        wishes: [for (var id = 1; id <= 15; id++) wishNamed(id, 'Wish $id')],
      );
      await tester.longPress(find.text('Wish 1'));
      await tester.pumpAndSettle();

      // The action bar stays lower than the bottom margin of the list: the
      // last wish keeps some space above it
      await tester.drag(
        find
            .descendant(
              of: find.byType(WishsTab).first,
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, -20000),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getBottomLeft(
              find.ancestor(
                of: find.text('Wish 15'),
                matching: find.byType(WishCard),
              ),
            )
            .dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(WishlistSelectionActionBar)).dy - 8,
        ),
      );
    });

    testWidgets('keeps the selection card at the height of the stats',
        (tester) async {
      await pumpOwnerWishlist(tester);
      final statsHeight = tester.getSize(find.byType(WishlistStatsCard).first);

      await tester.longPress(find.text(fakeWish1.name));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(WishlistSelectionCard)).height,
        statsHeight.height,
      );
    });

    testWidgets('does not cover the last wish with the action bar',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);

      final wishes = [
        for (var id = 1; id <= 15; id++) wishNamed(id, 'Wish $id'),
      ];
      await pumpOwnerWishlist(tester, wishes: wishes);

      await tester.longPress(find.text('Wish 1'));
      await tester.pumpAndSettle();

      await tester.drag(
        find
            .descendant(
              of: find.byType(WishsTab).first,
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();

      final lastWish = find.ancestor(
        of: find.text('Wish 15'),
        matching: find.byType(WishCard),
      );
      expect(
        tester.getBottomLeft(lastWish).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(WishlistSelectionActionBar)).dy,
        ),
      );
    });
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

  testWidgets('caches the wishlist theme once, outside of build',
      (tester) async {
    await tester.pumpRouterApp(
      WishlistRoute(wishlistId: 2).location,
      overrides: wishlistScreenOverrides(
        wishlistId: 2,
        wishlist: fakeWishlist2,
        wishes: fakeWishes,
      ),
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(WishlistScreen)));
    var writes = 0;
    container.listen(wishlistThemeCacheProvider(2), (_, __) => writes++);

    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Available to the screens that read it (wish cards, consult wish)
    final cached = container.read(wishlistThemeCacheProvider(2));
    expect(cached, isNotNull);
    expect(
      cached!.primaryColor,
      AppColors.getColorFromHexValue(fakeWishlist2.color),
    );
    expect(writes, 1);

    // Rebuilding the screen does not write the cache again
    container
        .read(wishlistScreenNotifierProvider(2).notifier)
        .enableSelectionMode(fakeWishes.first.id);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(writes, 1);
  });

  group('when loading fails', () {
    final l10n = AppLocalizationsFr();
    final networkError = AppException(
      statusCode: 500,
      cause: const SocketException('Failed host lookup'),
    );

    late int wishlistLoads;
    late int wishesLoads;

    List<Override> overrides({
      required Stream<IList<CompletedWishWithDetails>> Function()
          completedWishes,
    }) {
      return [
        supabaseClientOverride(userId: fakeCurrentUserId),
        userServiceOverride(userId: fakeCurrentUserId),
        watchWishlistByIdProvider(1).overrideWith((ref) {
          wishlistLoads++;
          return Stream.value(fakeWishlist1);
        }),
        watchWishsFromWishlistProvider(1).overrideWith((ref) {
          wishesLoads++;
          return wishesLoads == 1
              ? Stream.error(networkError)
              : Stream.value(fakeWishes.toIList());
        }),
        completedWishesRealtimeProvider.overrideWith(
          (ref) => Stream.value(const IListConst([])),
        ),
        completedWishesByUserRealtimeProvider(fakeWishlist1.idOwner)
            .overrideWith((ref) => completedWishes()),
      ];
    }

    setUp(() {
      wishlistLoads = 0;
      wishesLoads = 0;
    });

    testWidgets('shows the error without waiting for a hanging source',
        (tester) async {
      final hanging = StreamController<IList<CompletedWishWithDetails>>();
      addTearDown(hanging.close);

      await tester.pumpRouterApp(
        WishlistRoute(wishlistId: 1).location,
        overrides: overrides(completedWishes: () => hanging.stream),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.networkErrorTitle), findsOneWidget);
    });

    testWidgets('retries only the source that failed', (tester) async {
      await tester.pumpRouterApp(
        WishlistRoute(wishlistId: 1).location,
        overrides: overrides(
          completedWishes: () => Stream.value(const IListConst([])),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(wishesLoads, 2);
      expect(wishlistLoads, 1);
      expect(find.text(l10n.networkErrorTitle), findsNothing);
      expect(find.text(fakeWishes.first.name), findsWidgets);

      // Lets the delayed list animation and image placeholders run out
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
