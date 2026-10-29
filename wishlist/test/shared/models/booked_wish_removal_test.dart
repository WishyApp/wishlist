import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';

void main() {
  group('BookedWishRemoval.fromRow', () {
    test('reads the eight fields, removed_at in UTC', () {
      final removal = BookedWishRemoval.fromRow(const {
        'id': 42,
        'booker_id': 'booker',
        'owner_id': 'owner',
        'owner_pseudo': 'Lea',
        'wish_id': 7,
        'wish_name': 'Board game',
        'quantity': 2,
        'wishlist_name': 'Birthday',
        'removed_at': '2026-10-30T12:30:00+02:00',
        'dismissed_at': null,
      });

      expect(removal.id, 42);
      expect(removal.ownerId, 'owner');
      expect(removal.ownerPseudo, 'Lea');
      expect(removal.wishId, 7);
      expect(removal.wishName, 'Board game');
      expect(removal.quantity, 2);
      expect(removal.wishlistName, 'Birthday');
      expect(removal.removedAt, DateTime.utc(2026, 10, 30, 10, 30));
      expect(removal.removedAt.isUtc, isTrue);
    });
  });
}
