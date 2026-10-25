import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wishlist/modules/wishlists/infra/wishlist_screen_data_realtime_provider.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_stats_card.dart';
import 'package:wishlist/shared/infra/wish_mutations_provider.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wish/wish_sort_type.dart';
import 'package:wishlist/shared/theme/providers/wishlist_theme_provider.dart';
import 'package:wishlist/shared/theme/utils/get_wishlist_theme.dart';
import 'package:wishlist/shared/utils/string_utils.dart';

part 'wishlist_screen_notifier.freezed.dart';
part 'wishlist_screen_notifier.g.dart';

@freezed
class WishlistScreenState with _$WishlistScreenState {
  const factory WishlistScreenState({
    @Default(WishlistStatsCardType.pending)
    WishlistStatsCardType statCardSelected,
    @Default(
      WishSort(type: WishSortType.favorite, order: SortOrder.descending),
    )
    WishSort wishSort,
    @Default('') String searchQuery,
    @Default(false) bool isSelectionMode,
    @Default(<int>{}) Set<int> selectedWishIds,
  }) = _WishlistScreenState;
}

extension WishlistScreenSelection on WishlistScreenState {
  /// Vrai si tous les [wishIds] affichés sont sélectionnés : "Tout
  /// sélectionner" devient alors "Tout désélectionner"
  bool areAllSelected(Iterable<int> wishIds) =>
      wishIds.isNotEmpty && wishIds.every(selectedWishIds.contains);
}

@riverpod
class WishlistScreenNotifier extends _$WishlistScreenNotifier {
  late final TextEditingController searchController;
  late final FocusNode searchFocusNode;
  late final PageController pageController;
  var _isDisposed = false;

  @override
  WishlistScreenState build(int wishlistId) {
    _isDisposed = false;
    searchController = TextEditingController();
    searchFocusNode = FocusNode();
    pageController = PageController();

    searchController.addListener(() {
      final normalized = normalizeString(searchController.text);
      if (state.searchQuery != normalized) {
        state = state.copyWith(searchQuery: normalized);
      }
    });

    ref.onDispose(() {
      _isDisposed = true;
      searchController.dispose();
      searchFocusNode.dispose();
      pageController.dispose();
    });

    // Cache the theme when the data changes, not from the screen's build: the
    // wish screens read it through wishlistThemeProvider. The app theme is the
    // base of the screen's, so no context is needed.
    ref.listen(
      wishlistScreenDataRealtimeProvider(wishlistId),
      (_, next) {
        final wishlist = next.valueOrNull?.wishlist;
        if (wishlist != null) {
          cacheWishlistTheme(wishlist.id, getWishlistTheme(null, wishlist));
        }
      },
      fireImmediately: true,
    );

    return const WishlistScreenState();
  }

  void selectStatCard(WishlistStatsCardType type) {
    state = state.copyWith(statCardSelected: type);
    pageController.animateToPage(
      type.index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void onPageChanged(int index) {
    state = state.copyWith(
      statCardSelected: WishlistStatsCardType.values[index],
    );
  }

  void updateSort(WishSort sort) {
    state = state.copyWith(wishSort: sort);
  }

  void enableSelectionMode(int wishId) {
    state = state.copyWith(
      isSelectionMode: true,
      selectedWishIds: {...state.selectedWishIds, wishId},
    );
  }

  void toggleWishSelection(int wishId) {
    final newIds = {...state.selectedWishIds};
    if (newIds.contains(wishId)) {
      newIds.remove(wishId);
    } else {
      newIds.add(wishId);
    }
    state = state.copyWith(
      selectedWishIds: newIds,
      isSelectionMode: newIds.isNotEmpty,
    );
  }

  /// Ajoute [wishIds] (les wishs affichés) à la sélection, sans toucher aux
  /// wishs déjà sélectionnés que la recherche ou l'onglet masquent
  void selectAll(Iterable<int> wishIds) {
    if (wishIds.isEmpty) {
      return;
    }
    state = state.copyWith(
      isSelectionMode: true,
      selectedWishIds: {...state.selectedWishIds, ...wishIds},
    );
  }

  /// Retire [wishIds] (les wishs affichés) de la sélection. Comme pour un
  /// wish décoché à la main, le mode sélection se ferme quand elle est vide
  void deselectAll(Iterable<int> wishIds) {
    final newIds = state.selectedWishIds.difference(wishIds.toSet());
    state = state.copyWith(
      selectedWishIds: newIds,
      isSelectionMode: newIds.isNotEmpty,
    );
  }

  void exitSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedWishIds: {},
    );
  }

  Future<void> deleteSelectedWishs() async {
    final selectedIds = state.selectedWishIds;
    // Les wishs sont déjà chargés : on lit l'iconUrl sans aller-retour réseau
    // (et sans échouer si un wish a déjà été supprimé ailleurs).
    final wishs = ref
            .read(wishlistScreenDataRealtimeProvider(wishlistId))
            .valueOrNull
            ?.wishs ??
        <Wish>[].lock;
    final iconUrlById = {for (final w in wishs) w.id: w.iconUrl};
    for (final wishId in selectedIds) {
      // Les images (principale + miniature) sont supprimées avec le wish,
      // tant que la RLS du bucket autorise encore le propriétaire.
      await ref.read(wishMutationsProvider.notifier).delete(
            wishId,
            iconUrl: iconUrlById[wishId],
          );
    }
    exitSelectionMode();
  }

  Future<void> moveSelectedWishs(int targetWishlistId) async {
    final selectedIds = state.selectedWishIds;
    for (final wishId in selectedIds) {
      await ref.read(wishMutationsProvider.notifier).moveToWishlist(
            wishId: wishId,
            targetWishlistId: targetWishlistId,
          );
    }
    exitSelectionMode();
  }

  Future<void> toggleFavorite(Wish wish) async {
    final updatedWish = wish.copyWith(isFavourite: !wish.isFavourite);
    await ref.read(wishMutationsProvider.notifier).update(updatedWish);
  }

  Future<void> refreshData() async {
    ref.invalidate(wishlistScreenDataRealtimeProvider(wishlistId));
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void cacheWishlistTheme(int id, ThemeData theme) {
    // Évite de programmer une écriture à chaque reconstruction quand le thème
    // n'a pas changé (ThemeData compare par valeur)
    if (ref.read(wishlistThemeCacheProvider(id)) == theme) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The screen may be gone before the frame
      if (_isDisposed) {
        return;
      }
      ref.read(wishlistThemeCacheProvider(id).notifier).state = theme;
    });
  }
}
