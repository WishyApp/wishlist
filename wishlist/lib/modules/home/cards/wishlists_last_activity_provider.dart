import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_repository_provider.dart';

/// The last activity (newest wish added or edited) of each wishlist of the
/// user, by wishlist id, for the card of the lists left idle.
///
/// Its own provider, not part of `homeCardsProvider`: the query is a `max()`
/// per list, and the cards reload on a swipe or a change of bookings for data
/// that moves over days. Alive as long as the cards watch it (the home
/// screen), invalidated by the pull-to-refresh, when the home becomes the
/// current route again and when the app comes back to the foreground.
final wishlistsLastActivityProvider =
    FutureProvider.autoDispose<Map<int, DateTime>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) {
    return const {};
  }
  return ref.watch(wishlistRepositoryProvider).getLastActivityByWishlist();
});
