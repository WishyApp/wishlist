import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wish_taken_by_user/wish_taken_by_user.dart';

import '../../../fixtures/fake_data.dart';

void main() {
  WishTakenByUser booking(String userId, int quantity) => WishTakenByUser(
        wishId: 1,
        userId: userId,
        quantity: quantity,
        createdAt: fakeCreatedAt,
        updatedAt: fakeUpdatedAt,
      );

  /// The current user's booking of 1, plus [otherBookings] they can read
  BookedWishWithDetails bookedWish({
    int quantity = 3,
    required int receivedQuantity,
    List<WishTakenByUser> otherBookings = const [],
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
        takenByUser:
            [booking(fakeCurrentUserId, 1), ...otherBookings].toIList(),
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
      expect(bookedWish(receivedQuantity: 0).isGiven, isFalse);
    });

    test('receipts covering every booking make it given', () {
      // Only the current user booked it: 1 received of 3 is their gift
      expect(bookedWish(receivedQuantity: 1).isGiven, isTrue);
      expect(
        bookedWish(
          receivedQuantity: 2,
          otherBookings: [booking(fakeFriendUserId2, 1)],
        ).isGiven,
        isTrue,
      );
    });

    test('receipts covering part of the bookings leave it to give', () {
      expect(
        bookedWish(
          receivedQuantity: 1,
          otherBookings: [booking(fakeFriendUserId2, 1)],
        ).isGiven,
        isFalse,
      );
    });

    test('counts the booking itself when the bookings are not read', () {
      final withoutBookings = bookedWish(receivedQuantity: 1).copyWith(
        wish: Wish(
          id: 1,
          createdAt: fakeCreatedAt,
          name: 'Kindle',
          description: '',
          quantity: 3,
          wishlistId: 1,
          updatedBy: fakeFriendUserId1,
          updatedAt: fakeUpdatedAt,
        ),
        bookedQuantity: 2,
      );

      expect(withoutBookings.isGiven, isFalse);
    });
  });
}
