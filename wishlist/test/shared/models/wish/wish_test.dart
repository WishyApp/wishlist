import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/fake_data.dart';

void main() {
  group('Wish.bookableQuantity', () {
    final wish = fakeWish1.copyWith(quantity: 3);

    test('equals the available quantity when nothing was received', () {
      expect(wish.bookableQuantity(), 3);
    });

    test('subtracts the received quantity', () {
      expect(wish.bookableQuantity(receivedQuantity: 1), 2);
    });

    test('is 0 for a fully received wish', () {
      expect(wish.bookableQuantity(receivedQuantity: 3), 0);
    });

    test('never goes below 0 when booked and received exceed the quantity', () {
      expect(fakeWishBooked.bookableQuantity(receivedQuantity: 1), 0);
    });
  });
}
