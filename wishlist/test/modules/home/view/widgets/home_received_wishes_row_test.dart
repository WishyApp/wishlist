import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/modules/completed_wishes/view/completed_wishes_screen.dart';
import 'package:wishlist/modules/home/view/widgets/home_received_wishes_row.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/navigation/routes.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/fake_providers.dart';
import '../../../../pump_app.dart';

/// A wish received [daysAgo] days before [fakeNow]
CompletedWishWithDetails _completedWish(int id, {int daysAgo = 0}) {
  return CompletedWishWithDetails(
    wish: Wish(
      id: id,
      createdAt: fakeCreatedAt,
      name: 'Wish $id',
      description: '',
      quantity: 1,
      wishlistId: fakeWishlist1.id,
      updatedBy: fakeFriendUserId1,
      updatedAt: fakeUpdatedAt,
    ),
    fromWishlistId: fakeWishlist1.id,
    fromWishlistName: fakeWishlist1.name,
    ownerPseudo: fakeFriendProfile1.pseudo,
    ownerId: fakeFriendUserId1,
    completedAt: DateTime(
      fakeNow.year,
      fakeNow.month,
      fakeNow.day - daysAgo,
      12,
    ),
    quantity: 1,
  );
}

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    List<CompletedWishWithDetails> completedWishes = const [],
  }) async {
    await tester.pumpRouterApp(
      '/row',
      routes: [
        GoRoute(
          path: '/row',
          builder: (context, state) =>
              const Scaffold(body: SafeArea(child: HomeReceivedWishesRow())),
        ),
        ...$appRoutes,
      ],
      overrides: [
        ...homeScreenOverrides(completedWishes: completedWishes, now: fakeNow),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('is absent without a received wish', (tester) async {
    await pumpRow(tester);

    expect(find.byType(InkWell), findsNothing);
    expect(find.textContaining('reçu'), findsNothing);
  });

  testWidgets('shows the count and the date of the latest one', (tester) async {
    await pumpRow(
      tester,
      completedWishes: [
        _completedWish(1, daysAgo: 2),
        _completedWish(2, daysAgo: 10),
        _completedWish(3, daysAgo: 30),
      ],
    );

    expect(find.text('3 wishs reçus'), findsOneWidget);
    expect(find.text('Il y a 2 jours'), findsOneWidget);
  });

  testWidgets('opens the completed wishes', (tester) async {
    await pumpRow(tester, completedWishes: [_completedWish(1)]);

    expect(find.text('1 wish reçu'), findsOneWidget);

    await tester.tap(find.text('1 wish reçu'));
    await tester.pumpAndSettle();
    // Lets the initial load of the list finish
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CompletedWishesScreen), findsOneWidget);
  });
}
