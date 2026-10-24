import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wishlist/shared/models/wish/wish.dart';

part 'booked_wish_with_details.freezed.dart';
part 'booked_wish_with_details.g.dart';

@freezed
class BookedWishWithDetails with _$BookedWishWithDetails {
  const factory BookedWishWithDetails({
    required Wish wish,
    @JsonKey(name: 'booked_quantity') required int bookedQuantity,
    @JsonKey(name: 'wishlist_name') required String wishlistName,
    @JsonKey(name: 'owner_pseudo') required String ownerPseudo,
    @JsonKey(name: 'owner_id') required String ownerId,
    @JsonKey(name: 'owner_avatar_url') String? ownerAvatarUrl,

    /// Quantity of the wish the owner marked as received
    @JsonKey(name: 'received_quantity') @Default(0) int receivedQuantity,

    /// When the owner last changed the received quantity: the moment the
    /// wish became given, for a given one
    @JsonKey(name: 'received_at') DateTime? receivedAt,
  }) = _BookedWishWithDetails;

  const BookedWishWithDetails._();

  factory BookedWishWithDetails.fromJson(Map<String, dynamic> json) =>
      _$BookedWishWithDetailsFromJson(json);

  /// The owner's receipts cover all the bookings of the wish, this one
  /// included: the received quantity consumes the bookings first, as in
  /// [Wish.pendingQuantity]. Received items covering only part of the
  /// bookings leave them all to give, since nothing tells whose gift was
  /// received.
  ///
  /// The bookings are the ones the current user reads: on a private wishlist
  /// only their own, so another user's booking cannot keep theirs to give.
  bool get isGiven =>
      receivedQuantity > 0 &&
      receivedQuantity >= max(wish.totalBookedQuantity, bookedQuantity);
}
