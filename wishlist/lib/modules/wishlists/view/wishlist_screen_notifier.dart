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
  /// Vrai si tous les [wishIds] affichés sont sélectionnés (ou s'il n'y en a
  /// aucun) : "Tout sélectionner" n'a alors rien à ajouter
  bool areAllSelected(Iterable<int> wishIds) =>
      wishIds.every(selectedWishIds.contains);
}

@riverpod
class WishlistScreenNotifier extends _$WishlistScreenNotifier {
  late final TextEditingController searchController;
  late final FocusNode searchFocusNode;
  late final PageController pageController;
  var _isDisposed = false;

  /// Une action sur la sélection est en cours (voir [runOnSelection])
  var _isSelectionActionRunning = false;

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
      (previous, next) {
        final data = next.valueOrNull;
        if (data != null) {
          cacheWishlistTheme(
            data.wishlist.id,
            getWishlistTheme(null, data.wishlist),
          );
          // Pas au premier appel, pendant build : l'état n'existe pas encore,
          // et la sélection est vide
          if (previous != null) {
            _keepSelectionInWishs(data);
          }
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

  void exitSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedWishIds: {},
    );
  }

  /// Retire de la sélection les wishs qui ne sont plus dans la liste :
  /// supprimés ou déplacés ailleurs, ou entièrement reçus. Sans cela, le
  /// compteur les compterait et les actions s'y appliqueraient.
  void _keepSelectionInWishs(WishlistScreenData data) {
    if (_isSelectionActionRunning || state.selectedWishIds.isEmpty) {
      return;
    }
    final listedIds = {
      for (final wish in data.listedWishs(data.receivedQuantityById)) wish.id,
    };
    final kept = state.selectedWishIds.intersection(listedIds);
    if (kept.length == state.selectedWishIds.length) {
      return;
    }
    state = state.copyWith(
      selectedWishIds: kept,
      isSelectionMode: kept.isNotEmpty,
    );
  }

  /// Lance [action] sur les wishs sélectionnés, puis quitte le mode
  /// sélection. Pendant l'action, les wishs qu'elle traite quittent la liste
  /// un à un : la sélection n'est pas nettoyée avant la fin, sinon le mode
  /// sélection se fermerait en pleine action. En cas d'erreur, la sélection
  /// reste, sans les wishs qui ont quitté la liste.
  ///
  /// Renvoie le nombre de wishs traités, lu au lancement : la sélection a pu
  /// changer pendant une confirmation (0 si elle s'est vidée, sans action).
  Future<int> runOnSelection(
    Future<void> Function(Set<int> wishIds) action,
  ) async {
    final selectedIds = state.selectedWishIds;
    if (selectedIds.isEmpty) {
      return 0;
    }
    _isSelectionActionRunning = true;
    try {
      await action(selectedIds);
      if (!_isDisposed) {
        exitSelectionMode();
      }
      return selectedIds.length;
    } finally {
      _isSelectionActionRunning = false;
      final data = _isDisposed
          ? null
          : ref
              .read(wishlistScreenDataRealtimeProvider(wishlistId))
              .valueOrNull;
      if (data != null) {
        _keepSelectionInWishs(data);
      }
    }
  }

  Future<int> deleteSelectedWishs() => runOnSelection((selectedIds) async {
        // Les wishs sont déjà chargés : on lit l'iconUrl sans aller-retour
        // réseau (et sans échouer si un wish a déjà été supprimé ailleurs).
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
      });

  Future<int> moveSelectedWishs(int targetWishlistId) =>
      runOnSelection((selectedIds) async {
        for (final wishId in selectedIds) {
          await ref.read(wishMutationsProvider.notifier).moveToWishlist(
                wishId: wishId,
                targetWishlistId: targetWishlistId,
              );
        }
      });

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
