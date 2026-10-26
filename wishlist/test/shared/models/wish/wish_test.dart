import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/fake_data.dart';

void main() {
  group('Wish.pendingQuantity / bookableQuantity', () {
    final wish = fakeWish1.copyWith(quantity: 3);
    final bookedOne = wish.copyWith(
      takenByUser: [fakeWishTakenByUser.copyWith(wishId: wish.id)].toIList(),
    );

    test('equals the quantity when nothing is booked nor received', () {
      expect(wish.bookableQuantity(), 3);
      expect(wish.pendingQuantity(), 3);
    });

    test('received alone is subtracted', () {
      expect(wish.bookableQuantity(receivedQuantity: 1), 2);
    });

    test('is 0 for a fully received wish', () {
      expect(wish.bookableQuantity(receivedQuantity: 3), 0);
    });

    test('received consumes the bookings: booked 1, received 1 leaves 2', () {
      expect(bookedOne.bookableQuantity(receivedQuantity: 1), 2);
      expect(bookedOne.pendingQuantity(receivedQuantity: 1), 2);
    });

    test('booked above received: booked 1, received 0 leaves 2', () {
      expect(bookedOne.pendingQuantity(), 2);
    });

    test('received above booked: booked 1, received 2 leaves 1', () {
      expect(bookedOne.pendingQuantity(receivedQuantity: 2), 1);
    });

    test('ignoreBookings only subtracts the received quantity', () {
      final bookedTwo = wish.copyWith(
        takenByUser: [
          fakeWishTakenByUser.copyWith(wishId: wish.id, quantity: 2),
        ].toIList(),
      );

      expect(bookedOne.pendingQuantity(ignoreBookings: true), 3);
      expect(
        bookedTwo.pendingQuantity(receivedQuantity: 1, ignoreBookings: true),
        2,
      );
      expect(
        bookedTwo.pendingQuantity(receivedQuantity: 5, ignoreBookings: true),
        0,
      );
    });

    test('never goes below 0', () {
      expect(fakeWishBooked.bookableQuantity(receivedQuantity: 1), 0);
      expect(wish.bookableQuantity(receivedQuantity: 5), 0);
    });
  });

  group('Wish.remainingBookedQuantity', () {
    final wish = fakeWish1.copyWith(
      quantity: 5,
      takenByUser: [
        fakeWishTakenByUser.copyWith(wishId: fakeWish1.id, quantity: 3),
      ].toIList(),
    );

    test('equals the booked quantity when nothing is received', () {
      expect(wish.remainingBookedQuantity(), 3);
    });

    test('received consumes the bookings: booked 3, received 1 leaves 2', () {
      expect(wish.remainingBookedQuantity(receivedQuantity: 1), 2);
    });

    test('is 0 once the bookings are all received', () {
      expect(wish.remainingBookedQuantity(receivedQuantity: 3), 0);
    });

    test('never goes below 0', () {
      expect(wish.remainingBookedQuantity(receivedQuantity: 5), 0);
    });

    test('is 0 for a wish nobody booked', () {
      expect(fakeWish1.remainingBookedQuantity(receivedQuantity: 1), 0);
    });
  });
}
