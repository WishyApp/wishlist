import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_stream_repository_provider.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

final wishlistsRealtimeProvider =
    StreamProvider.autoDispose<List<Wishlist>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    // Signed out: an empty value replaces the previous user's one.
    return Stream.value(const []);
  }
  final repository = ref.watch(wishlistStreamRepositoryProvider);

  return repository
      .watchWishlistsByUser(userId)
      .map((wishlists) => wishlists.toList());
});
