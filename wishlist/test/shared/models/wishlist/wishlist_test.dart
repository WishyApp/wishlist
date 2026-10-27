import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/fake_data.dart';

void main() {
  group('Wishlist.hidesBookingsFrom', () {
    final hidden = fakeWishlist1.copyWith(canOwnerSeeTakenWish: false);
    final visible = fakeWishlist1.copyWith(canOwnerSeeTakenWish: true);

    test('hides the bookings from the owner when they are not shown', () {
      expect(hidden.hidesBookingsFrom(hidden.idOwner), isTrue);
    });

    test('does not hide them from the owner when they are shown', () {
      expect(visible.hidesBookingsFrom(visible.idOwner), isFalse);
    });

    test('does not hide them from another user', () {
      expect(hidden.hidesBookingsFrom('someone-else'), isFalse);
    });

    test('does not hide them without a session', () {
      expect(hidden.hidesBookingsFrom(null), isFalse);
    });
  });
}
