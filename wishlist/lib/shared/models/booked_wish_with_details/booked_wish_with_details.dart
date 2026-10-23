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

    /// When the owner first marked the wish as received
    @JsonKey(name: 'received_at') DateTime? receivedAt,
  }) = _BookedWishWithDetails;

  const BookedWishWithDetails._();

  factory BookedWishWithDetails.fromJson(Map<String, dynamic> json) =>
      _$BookedWishWithDetailsFromJson(json);

  /// The owner received the whole quantity of the wish: nothing is left to
  /// give. A partly received wish stays to give, since nothing tells which
  /// booking the received items came from.
  bool get isGiven => receivedQuantity > 0 && receivedQuantity >= wish.quantity;
}
