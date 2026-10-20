import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/wishlists/infra/wishlist_screen_data_realtime_provider.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/utils/wish_sort_utils.dart';

/// Listes de wishs affichées par l'écran wishlist, déjà ajustées des wishs
/// complétés, filtrées, triées et réparties entre disponibles et réservés.
/// Les wishs en attente se déduisent dans le body : ce sont tous les wishs si
/// le propriétaire ne voit pas les réservations, sinon les disponibles
typedef WishlistScreenDisplay = ({
  IList<Wish> all,
  IList<Wish> available,
  IList<Wish> booked,
  IMap<int, int> bookedQuantityOverrides,
});

const _emptyDisplay = (
  all: IListConst<Wish>([]),
  available: IListConst<Wish>([]),
  booked: IListConst<Wish>([]),
  bookedQuantityOverrides: IMapConst<int, int>({}),
);

/// Provider dérivé : le calcul coûteux ne dépend que des données de la
/// wishlist, du tri et de la recherche. Il n'est pas relancé quand la
/// sélection ou la carte de stats choisie changent. Le record utilise des
/// collections à égalité par valeur : un recalcul au résultat identique ne
/// notifie pas les watchers. Le provider est autoDispose : il ne doit pas
/// maintenir en vie le notifier de l'écran (contrôleurs, recherche, sélection).
final wishlistScreenDisplayProvider =
    Provider.autoDispose.family<WishlistScreenDisplay, int>((ref, wishlistId) {
  final data = ref.watch(wishlistScreenDataRealtimeProvider(wishlistId));
  final wishSort = ref.watch(
    wishlistScreenNotifierProvider(wishlistId).select((s) => s.wishSort),
  );
  final searchQuery = ref.watch(
    wishlistScreenNotifierProvider(wishlistId).select((s) => s.searchQuery),
  );

  final screenData = data.valueOrNull;
  if (screenData == null) {
    return _emptyDisplay;
  }

  final completedByWishId = <int, int>{
    for (final c in screenData.completedWishes) c.wish.id: c.quantity,
  };

  final adjustedWishs = screenData.wishs
      .where((w) => (completedByWishId[w.id] ?? 0) < w.quantity)
      .map((w) {
    final completedQty = completedByWishId[w.id] ?? 0;
    if (completedQty == 0) {
      return w;
    }
    return w.copyWith(quantity: w.quantity - completedQty);
  }).toIList();

  final wishs = WishSortUtils.sortAndFilterWishs(
    adjustedWishs,
    wishSort: wishSort,
    searchQuery: searchQuery,
  );

  final available = wishs.where((wish) => wish.availableQuantity > 0).toIList();

  final booked = wishs.where((wish) => wish.totalBookedQuantity > 0).toIList();

  final bookedQuantityOverrides = IMap<int, int>({
    for (final wish in booked)
      if ((completedByWishId[wish.id] ?? 0) > 0)
        wish.id: (wish.totalBookedQuantity - (completedByWishId[wish.id] ?? 0))
            .clamp(0, wish.totalBookedQuantity),
  });

  return (
    all: wishs,
    available: available,
    booked: booked,
    bookedQuantityOverrides: bookedQuantityOverrides,
  );
});
