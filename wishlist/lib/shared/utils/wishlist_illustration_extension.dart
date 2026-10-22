import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

/// Illustrations d'une wishlist sans wish. L'ordre est figé : il détermine
/// l'illustration associée à chaque wishlist.
final _noWishIllustrations = [
  Assets.svg.noWishBag,
  Assets.svg.noWishFlashlight,
  Assets.svg.noWishBoxHat,
];

/// Illustration "aucun wish" pour l'id d'une wishlist : un même id donne
/// toujours la même, quels que soient les rebuilds.
String noWishIllustrationFor(int wishlistId) =>
    _noWishIllustrations[wishlistId % _noWishIllustrations.length];

extension WishlistIllustrationExtension on Wishlist {
  /// Illustration affichée quand la wishlist n'a aucun wish.
  String get noWishIllustration => noWishIllustrationFor(id);
}
