import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/wishlists/infra/wishlist_screen_data_realtime_provider.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/utils/wish_sort_utils.dart';

/// Listes de wishs affichées par l'écran wishlist, déjà ajustées des wishs
/// complétés, filtrées, triées et réparties entre en attente et réservés.
/// Les wishs entièrement reçus sont exclus, et ceux dont toutes les
/// réservations sont reçues quittent les réservés. Les quantités affichées ne
/// sont pas réduites : les overrides portent la quantité en attente / réservée
/// restante.
/// Les wishs en attente (`pending`) et leurs quantités sont déjà résolus.
/// `bookingsHidden` dit si les réservations sont masquées pour l'utilisateur
/// courant (Wishlist.hidesBookingsFrom).
/// Dans ce cas, la quantité en attente est quantité - reçu. L'utilisateur
/// peut encore lire sa propre réservation (ligne héritée) : elle ne doit pas
/// s'en déduire.
/// Sinon, les réservations se déduisent de la quantité en attente.
typedef WishlistScreenDisplay = ({
  IList<Wish> all,
  IList<Wish> pending,
  IList<Wish> booked,
  // Ids des listes ci-dessus, pour "Tout sélectionner" : calculés ici une
  // fois par changement de données, de tri ou de recherche
  IList<int> allIds,
  IList<int> availableIds,
  IList<int> bookedIds,
  IMap<int, int> pendingQuantityOverrides,
  IMap<int, int> bookedQuantityOverrides,
  bool bookingsHidden,
});

const _emptyDisplay = (
  all: IListConst<Wish>([]),
  pending: IListConst<Wish>([]),
  booked: IListConst<Wish>([]),
  allIds: IListConst<int>([]),
  availableIds: IListConst<int>([]),
  bookedIds: IListConst<int>([]),
  pendingQuantityOverrides: IMapConst<int, int>({}),
  bookedQuantityOverrides: IMapConst<int, int>({}),
  bookingsHidden: false,
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
  final currentUserId = ref.watch(currentUserIdProvider);

  final screenData = data.valueOrNull;
  if (screenData == null) {
    return _emptyDisplay;
  }

  final completedByWishId = screenData.receivedQuantityById;

  // Un wish entièrement reçu n'est ni en attente ni à offrir.
  final adjustedWishs = screenData.listedWishs(completedByWishId);

  final wishs = WishSortUtils.sortAndFilterWishs(
    adjustedWishs,
    wishSort: wishSort,
    searchQuery: searchQuery,
  );

  // Réservations masquées : elles ne comptent pas dans l'attente (quantité -
  // reçu) et tous les wishs restent listés. Sinon, en attente = quantité -
  // max(réservé, reçu), comme sur l'écran du wish et côté serveur.
  final hidden = screenData.wishlist.hidesBookingsFrom(currentUserId);
  int pendingQuantityOf(Wish wish) => wish.pendingQuantity(
        receivedQuantity: completedByWishId[wish.id] ?? 0,
        ignoreBookings: hidden,
      );

  // Masqué, tous les wishs non reçus restent en attente : les wishs
  // entièrement reçus sont déjà exclus plus haut.
  final pending = wishs.where((wish) => pendingQuantityOf(wish) > 0).toIList();

  final pendingQuantityOverrides = IMap<int, int>({
    for (final wish in wishs) wish.id: pendingQuantityOf(wish),
  });

  // Réservé restant = réservé - reçu : la quantité reçue consomme d'abord les
  // réservations. Un wish dont toutes les réservations sont reçues n'est plus
  // listé comme réservé.
  // Limite des wishlists privées : voir Wish.remainingBookedQuantity. Même
  // comportement que BookedWishWithDetails.isGiven et l'écran du wish.
  int remainingBookedQuantityOf(Wish wish) => wish.remainingBookedQuantity(
        receivedQuantity: completedByWishId[wish.id] ?? 0,
      );

  final booked =
      wishs.where((wish) => remainingBookedQuantityOf(wish) > 0).toIList();

  final bookedQuantityOverrides = IMap<int, int>({
    for (final wish in booked) wish.id: remainingBookedQuantityOf(wish),
  });

  return (
    all: wishs,
    pending: pending,
    booked: booked,
    allIds: wishs.map((wish) => wish.id).toIList(),
    availableIds: pending.map((wish) => wish.id).toIList(),
    bookedIds: booked.map((wish) => wish.id).toIList(),
    pendingQuantityOverrides: pendingQuantityOverrides,
    bookedQuantityOverrides: bookedQuantityOverrides,
    bookingsHidden: hidden,
  );
});
