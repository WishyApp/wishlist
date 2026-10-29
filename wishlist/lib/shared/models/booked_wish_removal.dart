import 'package:flutter/foundation.dart';

/// A wish the current user had booked that its owner removed (row of
/// `booked_wish_removals`, written by database triggers).
///
/// No image: the images of a wish are deleted with the wish.
@immutable
class BookedWishRemoval {
  const BookedWishRemoval({
    required this.id,
    required this.ownerId,
    required this.ownerPseudo,
    required this.wishId,
    required this.wishName,
    required this.quantity,
    required this.wishlistName,
    required this.removedAt,
  });

  /// One row of `booked_wish_removals`. Throws if a column is missing or has
  /// the wrong type.
  factory BookedWishRemoval.fromRow(Map<String, dynamic> row) {
    return BookedWishRemoval(
      id: row['id'] as int,
      ownerId: row['owner_id'] as String,
      ownerPseudo: row['owner_pseudo'] as String,
      wishId: row['wish_id'] as int,
      wishName: row['wish_name'] as String,
      quantity: row['quantity'] as int,
      wishlistName: row['wishlist_name'] as String,
      removedAt: DateTime.parse(row['removed_at'] as String).toUtc(),
    );
  }

  final int id;
  final String ownerId;

  /// Pseudo of the owner when the wish was removed, copied into the row: the
  /// booker may no longer be allowed to read the owner's profile. Empty when
  /// the owner had none.
  final String ownerPseudo;

  /// Id of the removed wish. It no longer exists: do not look it up.
  final int wishId;
  final String wishName;

  /// Quantity booked by the current user.
  final int quantity;
  final String wishlistName;
  final DateTime removedAt;

  @override
  bool operator ==(Object other) =>
      other is BookedWishRemoval &&
      other.id == id &&
      other.ownerId == ownerId &&
      other.ownerPseudo == ownerPseudo &&
      other.wishId == wishId &&
      other.wishName == wishName &&
      other.quantity == quantity &&
      other.wishlistName == wishlistName &&
      other.removedAt == removedAt;

  @override
  int get hashCode => Object.hash(
        id,
        ownerId,
        ownerPseudo,
        wishId,
        wishName,
        quantity,
        wishlistName,
        removedAt,
      );
}
