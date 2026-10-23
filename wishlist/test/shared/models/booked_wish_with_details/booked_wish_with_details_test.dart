import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';

import '../../../fixtures/fake_data.dart';

void main() {
  BookedWishWithDetails bookedWish({
    required int quantity,
    required int receivedQuantity,
  }) {
    return BookedWishWithDetails(
      wish: Wish(
        id: 1,
        createdAt: fakeCreatedAt,
        name: 'Kindle',
        description: '',
        quantity: quantity,
        wishlistId: 1,
        updatedBy: fakeFriendUserId1,
        updatedAt: fakeUpdatedAt,
      ),
      bookedQuantity: 1,
      wishlistName: 'Noël',
      ownerPseudo: 'Alice',
      ownerId: fakeFriendUserId1,
      receivedQuantity: receivedQuantity,
    );
  }

  group('isGiven', () {
    test('a wish not received is left to give', () {
      expect(bookedWish(quantity: 1, receivedQuantity: 0).isGiven, isFalse);
    });

    test('a wish received in full is given', () {
      expect(bookedWish(quantity: 1, receivedQuantity: 1).isGiven, isTrue);
      expect(bookedWish(quantity: 3, receivedQuantity: 3).isGiven, isTrue);
    });

    test('a wish partly received is still left to give', () {
      expect(bookedWish(quantity: 3, receivedQuantity: 1).isGiven, isFalse);
    });
  });
}
