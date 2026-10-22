import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

void main() {
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

  Future<void> pumpFriendView(
    WidgetTester tester, {
    required Wish wish,
    required int receivedQuantity,
    WishQuantityDisplay quantityDisplay = WishQuantityDisplay.total,
  }) async {
    await tester.pumpApp(
      ConsultWishScreen(
        wishIds: const [1],
        initialIndex: 0,
        quantityDisplay: quantityDisplay,
      ),
      overrides: wishScreenOverrides(
        wishId: wish.id,
        wishlistId: wish.wishlistId,
        wish: wish,
        wishlist: friendWishlist,
        receipts: () => Stream.value(
          (receivedQuantity > 0
                  ? [received(wish, receivedQuantity)]
                  : <CompletedWishWithDetails>[])
              .toIList(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String giveItLabel(WidgetTester tester) =>
      tester.element(find.byType(ConsultWishScreen)).l10n.iWantToGiveIt;

  testWidgets('shows the give button while a quantity is still pending',
      (tester) async {
    await pumpFriendView(
      tester,
      wish: fakeWish1.copyWith(quantity: 2),
      receivedQuantity: 1,
    );

    expect(find.text(giveItLabel(tester)), findsWidgets);
  });

  testWidgets('hides the give button when the wish is fully received',
      (tester) async {
    await pumpFriendView(
      tester,
      wish: fakeWish1.copyWith(quantity: 2),
      receivedQuantity: 2,
    );

    expect(find.text(giveItLabel(tester)), findsNothing);
  });

  testWidgets('shows the give button when the received item was booked',
      (tester) async {
    // Quantité 2, 1 réservé et 1 reçu : 2 - max(1, 1) = 1 encore à offrir.
    final wish = fakeWish1.copyWith(
      quantity: 2,
      takenByUser:
          [fakeWishTakenByUser.copyWith(wishId: fakeWish1.id)].toIList(),
    );
    await pumpFriendView(tester, wish: wish, receivedQuantity: 1);

    expect(find.text(giveItLabel(tester)), findsWidgets);
  });

  testWidgets('hides the give button when received covers the quantity',
      (tester) async {
    final wish = fakeWish1.copyWith(
      quantity: 1,
      takenByUser:
          [fakeWishTakenByUser.copyWith(wishId: fakeWish1.id)].toIList(),
    );
    await pumpFriendView(tester, wish: wish, receivedQuantity: 1);

    expect(find.text(giveItLabel(tester)), findsNothing);
  });

  testWidgets('pending quantity counts what the owner received',
      (tester) async {
    // Quantité 4, 1 réservé, 2 reçus par le propriétaire : 4 - max(1, 2) = 2.
    final wish = fakeWish1.copyWith(
      quantity: 4,
      takenByUser:
          [fakeWishTakenByUser.copyWith(wishId: fakeWish1.id)].toIList(),
    );
    await pumpFriendView(
      tester,
      wish: wish,
      receivedQuantity: 2,
      quantityDisplay: WishQuantityDisplay.pending,
    );

    expect(find.text('x2'), findsOneWidget);
  });
}
