import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/year_recap/most_gifted_friend.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';

import '../../fixtures/fake_data.dart';

DateTime on(int year, int month, int day) => DateTime(year, month, day, 12);

BookedWishWithDetails offered(
  int id, {
  required DateTime? receivedAt,
  String ownerId = fakeFriendUserId1,
  String ownerPseudo = 'Alice',
  int bookedQuantity = 1,
  int? receivedQuantity,
}) {
  return BookedWishWithDetails(
    wish: Wish(
      id: id,
      createdAt: fakeCreatedAt,
      name: 'Wish $id',
      description: '',
      quantity: 1,
      wishlistId: 1,
      updatedBy: fakeFriendUserId1,
      updatedAt: fakeUpdatedAt,
    ),
    bookedQuantity: bookedQuantity,
    receivedQuantity: receivedQuantity ?? (receivedAt == null ? 0 : 1),
    wishlistName: 'Liste',
    ownerPseudo: ownerPseudo,
    ownerId: ownerId,
    receivedAt: receivedAt,
  );
}

void main() {
  test('the most gifted friend is the one who got the most wishes', () {
    final pseudo = mostGiftedFriendPseudo(
      bookings: [
        offered(10, receivedAt: on(2026, 1, 1)),
        offered(
          11,
          receivedAt: on(2026, 2, 1),
          ownerId: fakeFriendUserId2,
          ownerPseudo: 'Bob',
        ),
        offered(
          12,
          receivedAt: on(2026, 3, 1),
          ownerId: fakeFriendUserId2,
          ownerPseudo: 'Bob',
        ),
      ],
      year: 2026,
    );

    expect(pseudo, 'Bob');
  });

  test('a tie, or nothing offered, gives no most gifted friend', () {
    final tie = mostGiftedFriendPseudo(
      bookings: [
        offered(10, receivedAt: on(2026, 1, 1)),
        offered(
          11,
          receivedAt: on(2026, 2, 1),
          ownerId: fakeFriendUserId2,
          ownerPseudo: 'Bob',
        ),
      ],
      year: 2026,
    );

    expect(tie, isNull);
    expect(mostGiftedFriendPseudo(bookings: const [], year: 2026), isNull);
  });

  test('a booking counts once its booked quantity is received, in the year',
      () {
    final pseudo = mostGiftedFriendPseudo(
      bookings: [
        // 1 of the 2 booked received: not offered yet
        offered(
          10,
          receivedAt: on(2026, 5, 1),
          bookedQuantity: 2,
          receivedQuantity: 1,
        ),
        // Last year, or not received: not this year's
        offered(11, receivedAt: on(2025, 5, 1)),
        offered(12, receivedAt: null),
      ],
      year: 2026,
    );

    expect(pseudo, isNull);
  });
}
