import 'package:async_value_group/async_value_group.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

// autoDispose: keyed by wishlist id, not by user. Kept alive, it would hold
// the streams (and their channels) opened under a previous session, and serve
// them to the next user opening the same wishlist.
final wishlistScreenDataRealtimeProvider = Provider.autoDispose
    .family<AsyncValue<WishlistScreenData>, int>((ref, wishlistId) {
  final wishlistAsync = ref.watch(watchWishlistByIdProvider(wishlistId));
  final wishs = ref.watch(watchWishsFromWishlistProvider(wishlistId));
  final wishlist = wishlistAsync.valueOrNull;

  // Une wishlist supprimée ou archivée est gérée par WishlistScreen
  if (wishlist == null) {
    return switch (wishlistAsync) {
      AsyncError(:final error, :final stackTrace) =>
        AsyncError(error, stackTrace),
      _ => const AsyncLoading(),
    };
  }

  final completedWishes =
      ref.watch(completedWishesByUserRealtimeProvider(wishlist.idOwner));

  // group3 reports loading before errors: a source that failed (timed out)
  // must not wait for another one still hanging
  for (final source in [wishlistAsync, wishs, completedWishes]) {
    if (source case AsyncError(:final error, :final stackTrace)) {
      return AsyncError(error, stackTrace);
    }
  }

  return AsyncValueGroup.group3(
    wishlistAsync.whenData((_) => wishlist),
    wishs,
    completedWishes,
  );
});

typedef WishlistScreenData = (
  Wishlist wishlist,
  IList<Wish> wishs,
  IList<CompletedWishWithDetails> completedWishes,
);

extension WishlistScreenDataGetters on WishlistScreenData {
  Wishlist get wishlist => $1;
  IList<Wish> get wishs => $2;
  IList<CompletedWishWithDetails> get completedWishes => $3;

  /// Quantité déjà reçue de chaque wish complété
  Map<int, int> get receivedQuantityById => {
        for (final c in completedWishes) c.wish.id: c.quantity,
      };

  /// Wishs que l'écran liste : un wish entièrement reçu n'est ni en attente
  /// ni à offrir. Règle partagée par l'affichage et la sélection.
  IList<Wish> listedWishs(Map<int, int> receivedQuantityById) => wishs
      .where((w) => (receivedQuantityById[w.id] ?? 0) < w.quantity)
      .toIList();
}
