// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booked_wish_with_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookedWishWithDetailsImpl _$$BookedWishWithDetailsImplFromJson(
        Map<String, dynamic> json) =>
    _$BookedWishWithDetailsImpl(
      wish: Wish.fromJson(json['wish'] as Map<String, dynamic>),
      bookedQuantity: (json['booked_quantity'] as num).toInt(),
      wishlistName: json['wishlist_name'] as String,
      ownerPseudo: json['owner_pseudo'] as String,
      ownerId: json['owner_id'] as String,
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
      receivedQuantity: (json['received_quantity'] as num?)?.toInt() ?? 0,
      receivedAt: json['received_at'] == null
          ? null
          : DateTime.parse(json['received_at'] as String),
    );

Map<String, dynamic> _$$BookedWishWithDetailsImplToJson(
        _$BookedWishWithDetailsImpl instance) =>
    <String, dynamic>{
      'wish': instance.wish,
      'booked_quantity': instance.bookedQuantity,
      'wishlist_name': instance.wishlistName,
      'owner_pseudo': instance.ownerPseudo,
      'owner_id': instance.ownerId,
      'owner_avatar_url': instance.ownerAvatarUrl,
      'received_quantity': instance.receivedQuantity,
      'received_at': instance.receivedAt?.toIso8601String(),
    };
