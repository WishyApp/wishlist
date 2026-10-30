import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:wishlist/shared/models/wishlist/create_request/wishlist_create_request.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

abstract class WishlistRepository {
  Future<Wishlist> createWishlist(WishlistCreateRequest wishlist);

  Future<IList<Wishlist>> getWishlistsByUser(String userId);

  Future<IList<Wishlist>> getPublicWishlistsByUser(String userId);

  Future<int> getNbWishlistsByUser(String userId);

  /// Renvoie `null` si la wishlist n'existe pas ou a été archivée
  Future<Wishlist?> findWishlistById(int wishlistId);

  Future<Wishlist> updateWishlist(Wishlist wishlist);

  Future<void> deleteWishlist(int wishlistId);

  /// The most recent activity (creation, wishes added or changed) of each
  /// open wishlist of the current user, by wishlist id.
  Future<Map<int, DateTime>> getLastActivityByWishlist();
}
