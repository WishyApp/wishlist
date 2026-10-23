import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/completed_wishes/view/completed_wishes_screen.dart';
import 'package:wishlist/modules/friends/view/screens/friend_details_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/friend_details_realtime_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/widgets/wishlist_card.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

/// A wish of the friend, completed [daysAgo] days ago (relative to now, so
/// that the date shown in the goldens does not change over time)
CompletedWishWithDetails _completedWish(
  int id, {
  String? name,
  int daysAgo = 0,
  int quantity = 1,
}) {
  return CompletedWishWithDetails(
    wish: Wish(
      id: id,
      createdAt: fakeCreatedAt,
      name: name ?? 'Wish $id',
      description: '',
      quantity: quantity,
      wishlistId: fakeWishlist1.id,
      updatedBy: fakeFriendUserId1,
      updatedAt: fakeUpdatedAt,
    ),
    fromWishlistId: fakeWishlist1.id,
    fromWishlistName: fakeWishlist1.name,
    ownerPseudo: fakeFriendProfile1.pseudo,
    ownerId: fakeFriendUserId1,
    completedAt: DateTime.now().subtract(Duration(days: daysAgo)),
    quantity: quantity,
  );
}

void main() {
  final l10n = AppLocalizationsFr();

  testAdaptiveWidgets('$FriendDetailsScreen golden test',
      (tester, variant) async {
    await tester.pumpRouterApp(
      FriendDetailsRoute(fakeFriendUserId1).location,
      windowConfig: variant,
      overrides: friendDetailsScreenOverrides(
        friendId: fakeFriendUserId1,
        completedWishes: [
          _completedWish(1, name: 'Casque Sony WH-1000XM5'),
          _completedWish(2, name: 'Kindle Paperwhite', daysAgo: 3),
          _completedWish(3, name: 'Cafetière Bialetti', daysAgo: 14),
          _completedWish(4, name: 'Plaid en laine', daysAgo: 20, quantity: 2),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<FriendDetailsScreen>(variant);
  });

  testAdaptiveWidgets('$FriendDetailsScreen when empty',
      (tester, variant) async {
    await tester.pumpRouterApp(
      FriendDetailsRoute(fakeFriendUserId1).location,
      windowConfig: variant,
      overrides: friendDetailsScreenOverrides(
        friendId: fakeFriendUserId1,
        friendDetails: fakeFriendDetailsEmpty,
      ),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<FriendDetailsScreen>(variant, suffix: 'empty');
  });

  testWidgets('$FriendDetailsScreen hides the completed wishes when none',
      (tester) async {
    await tester.pumpRouterApp(
      FriendDetailsRoute(fakeFriendUserId1).location,
      overrides: friendDetailsScreenOverrides(friendId: fakeFriendUserId1),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.friendCompletedWishesTitle), findsNothing);
    expect(find.text(l10n.seeAllCompletedWishes), findsNothing);
  });

  testWidgets(
      '$FriendDetailsScreen shows the most recent completed wishes and '
      'their total', (tester) async {
    await tester.pumpRouterApp(
      FriendDetailsRoute(fakeFriendUserId1).location,
      overrides: friendDetailsScreenOverrides(
        friendId: fakeFriendUserId1,
        // Unordered on purpose: the carousel sorts them, most recent first
        completedWishes: [
          for (var id = 12; id >= 1; id--) _completedWish(id, daysAgo: id),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.friendCompletedWishesTitle), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    for (var id = 1; id <= 10; id++) {
      expect(find.text('Wish $id'), findsOneWidget);
    }
    expect(find.text('Wish 11'), findsNothing);
    expect(find.text('Wish 12'), findsNothing);
    expect(find.text('Hier'), findsOneWidget);
    expect(find.text('Il y a 3 jours'), findsOneWidget);

    final firstCard = tester.getTopLeft(find.text('Wish 1'));
    final secondCard = tester.getTopLeft(find.text('Wish 2'));
    expect(secondCard.dx, greaterThan(firstCard.dx));
    expect(secondCard.dy, firstCard.dy);
  });

  testWidgets(
      '$FriendDetailsScreen opens all the completed wishes of the friend, '
      'read-only', (tester) async {
    await tester.pumpRouterApp(
      FriendDetailsRoute(fakeFriendUserId1).location,
      overrides: friendDetailsScreenOverrides(
        friendId: fakeFriendUserId1,
        completedWishes: [
          for (var id = 1; id <= 12; id++) _completedWish(id, daysAgo: id),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.seeAllCompletedWishes));
    await tester.pumpAndSettle();

    final screen = tester.widget<CompletedWishesScreen>(
      find.byType(CompletedWishesScreen),
    );
    expect(screen.userId, fakeFriendUserId1);
    expect(find.text('Wish 1'), findsOneWidget);
    // The friend's wishes cannot be uncompleted from here
    expect(find.byIcon(Icons.undo), findsNothing);
  });

  testWidgets('$FriendDetailsScreen explains a load error and retries',
      (tester) async {
    var loads = 0;

    await tester.pumpPushedScreen(
      const FriendDetailsScreen(friendId: fakeFriendUserId1),
      overrides: [
        supabaseClientOverride(),
        friendDetailsRealtimeProvider(fakeFriendUserId1).overrideWith((ref) {
          loads++;
          return loads == 1
              ? Stream.error(
                  AppException(
                    statusCode: 500,
                    cause: const SocketException('Failed host lookup'),
                  ),
                )
              : Stream.value(fakeFriendDetails);
        }),
      ],
    );

    expect(find.text(l10n.networkErrorTitle), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text(l10n.networkErrorTitle), findsNothing);
    expect(find.text(fakeFriendDetails.appUser.profile.pseudo), findsWidgets);
    // The loaded screen has a single Scaffold, besides the one of the test app
    expect(find.byType(Scaffold), findsNWidgets(2));
  });

  testWidgets(
      '$FriendDetailsScreen keeps the last wishlist above the home '
      'indicator', (tester) async {
    const bottomInset = 34.0;
    // Short enough for the list to scroll
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 400)
      ..padding = const FakeViewPadding(bottom: bottomInset)
      ..viewPadding = const FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.reset);

    await tester.pumpPushedScreen(
      const FriendDetailsScreen(friendId: fakeFriendUserId1),
      overrides: friendDetailsScreenOverrides(friendId: fakeFriendUserId1),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final lastWishlist = find.byType(WishlistCard).last;
    expect(
      tester.getBottomLeft(lastWishlist).dy,
      lessThanOrEqualTo(400 - bottomInset),
    );
  });
}
