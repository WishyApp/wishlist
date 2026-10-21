import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_stream_repository_provider.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/utils/first_event_timeout.dart';

final watchWishlistsByUserProvider =
    StreamProvider.autoDispose.family<IList<Wishlist>, String>((ref, userId) {
  final repository = ref.watch(wishlistStreamRepositoryProvider);
  return repository.watchWishlistsByUser(userId);
});

final watchWishlistByIdProvider =
    StreamProvider.autoDispose.family<Wishlist?, int>((ref, wishlistId) {
  final repository = ref.watch(wishlistStreamRepositoryProvider);
  return repository.watchWishlistById(wishlistId).timeoutFirstEvent();
});

final watchPublicWishlistsByUserProvider =
    StreamProvider.autoDispose.family<IList<Wishlist>, String>((ref, userId) {
  final repository = ref.watch(wishlistStreamRepositoryProvider);
  return repository.watchPublicWishlistsByUser(userId);
});
