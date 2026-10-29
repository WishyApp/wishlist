import 'dart:math';

import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';

/// Pseudo of the friend the user gave the most wishes to during [year], null
/// on a tie or when nothing was given. The server does not return pseudos:
/// this comes from the bookings the app already has. A booking counts as given
/// once the owner marked at least the booked quantity as received
/// (`receivedAt` in [year]).
String? mostGiftedFriendPseudo({
  required List<BookedWishWithDetails> bookings,
  required int year,
}) {
  final givenByOwner = <String, int>{};
  final pseudos = <String, String>{};
  for (final booking in bookings) {
    if (booking.receivedAt?.toLocal().year == year &&
        booking.receivedQuantity >= booking.bookedQuantity) {
      givenByOwner.update(booking.ownerId, (n) => n + 1, ifAbsent: () => 1);
      pseudos[booking.ownerId] = booking.ownerPseudo;
    }
  }
  final most = givenByOwner.values.fold(0, max);
  final top = [
    for (final entry in givenByOwner.entries)
      if (entry.value == most) entry.key,
  ];
  return top.length == 1 ? pseudos[top.single] : null;
}
