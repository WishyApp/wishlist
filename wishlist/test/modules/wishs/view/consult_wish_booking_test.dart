import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
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
  }) async {
    await tester.pumpApp(
      const ConsultWishScreen(wishIds: [1], initialIndex: 0),
      overrides: [
        ...wishScreenOverrides(
          wishId: wish.id,
          wishlistId: wish.wishlistId,
          wish: wish,
          wishlist: friendWishlist,
        ),
        completedWishesByUserRealtimeProvider(fakeFriendUserId1).overrideWith(
          (ref) => Stream.value(
            (receivedQuantity > 0
                    ? [received(wish, receivedQuantity)]
                    : <CompletedWishWithDetails>[])
                .toIList(),
          ),
        ),
      ],
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
}
