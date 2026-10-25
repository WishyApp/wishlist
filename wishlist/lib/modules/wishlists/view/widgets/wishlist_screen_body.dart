import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/wishlists/infra/wishlist_screen_data_realtime_provider.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_search_bar.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_selection_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_stats_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_stats_section.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishs_tab.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_display_provider.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/widgets/inert_switcher_layout.dart';

class WishlistScreenBody extends ConsumerWidget {
  const WishlistScreenBody({
    super.key,
    required this.wishlistId,
    required this.wishlistScreenData,
    required this.isMyWishlist,
  });

  static const Duration _cardsFadeDuration = Duration(milliseconds: 250);

  final int wishlistId;
  final WishlistScreenData wishlistScreenData;
  final bool isMyWishlist;

  void _onTapWish(
    BuildContext context,
    WidgetRef ref,
    Wish wish, {
    required IList<Wish> wishsToDisplay,
    required WishlistStatsCardType cardType,
  }) {
    final screenState = ref.read(wishlistScreenNotifierProvider(wishlistId));

    if (screenState.isSelectionMode) {
      ref
          .read(wishlistScreenNotifierProvider(wishlistId).notifier)
          .toggleWishSelection(wish.id);
      return;
    }

    final wishIds = wishsToDisplay.map((w) => w.id).toList();

    ConsultWishRoute(
      wish.wishlistId,
      wish.id,
      wishIds: wishIds,
      quantityDisplay: cardType == WishlistStatsCardType.pending
          ? WishQuantityDisplay.pending
          : WishQuantityDisplay.booked,
    ).push(context);
  }

  WishsTab _buildWishsTab(
    BuildContext context,
    WidgetRef ref, {
    required Wishlist wishlist,
    required IList<Wish> wishs,
    required bool shouldDisplay,
    required WishlistStatsCardType cardType,
    required bool isWishsBookedHidden,
    required WishlistScreenState screenState,
    required WishlistScreenNotifier notifier,
    Map<int, int>? quantityOverrideMap,
  }) {
    return WishsTab(
      wishlist: wishlist,
      wishsToDisplay: wishs,
      shouldDisplayWishs: shouldDisplay,
      statCardSelected: cardType,
      isWishsBookedHidden: isWishsBookedHidden,
      isMyWishlist: isMyWishlist,
      quantityOverrideMap: quantityOverrideMap,
      onTapWish: (
        context,
        wish, {
        required wishsToDisplay,
        cardType,
      }) =>
          _onTapWish(
        context,
        ref,
        wish,
        wishsToDisplay: wishsToDisplay,
        cardType: cardType!,
      ),
      onAddWish: (context, wishlist) =>
          CreateWishRoute(wishlistId: wishlist.id).push(context),
      onFavoriteToggle: (wish) async {
        try {
          await notifier.toggleFavorite(wish);
        } catch (e) {
          if (context.mounted) {
            showGenericError(context, error: e);
          }
        }
      },
      onRefresh: notifier.refreshData,
      isSelectionMode: screenState.isSelectionMode,
      selectedWishIds: screenState.selectedWishIds,
      onLongPressWish: isMyWishlist ? notifier.enableSelectionMode : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenState = ref.watch(wishlistScreenNotifierProvider(wishlistId));
    final notifier =
        ref.read(wishlistScreenNotifierProvider(wishlistId).notifier);

    final wishlist = wishlistScreenData.wishlist;

    // Le calcul des listes ne dépend que des données, du tri et de la
    // recherche : la sélection et la carte de stats ne le relancent pas
    final display = ref.watch(wishlistScreenDisplayProvider(wishlistId));
    final wishs = display.all;
    final wishsBooked = display.booked;
    final pendingQuantityOverrides = display.pendingQuantityOverrides;
    final bookedQuantityOverrides = display.bookedQuantityOverrides;
    final isWishsBookedHidden = !wishlist.canOwnerSeeTakenWish && isMyWishlist;
    final wishsPending = isWishsBookedHidden ? wishs : display.available;

    final nbWishsPending = wishsPending.length;
    final nbWishsBooked = wishsBooked.length;

    // Wishs affichés par l'onglet courant, avec la recherche et le tri en
    // cours : ceux que "Tout sélectionner" coche
    final visibleWishIds = switch (screenState.statCardSelected) {
      WishlistStatsCardType.pending => wishsPending,
      WishlistStatsCardType.booked =>
        isWishsBookedHidden ? const IListConst<Wish>([]) : wishsBooked,
    }
        .map((wish) => wish.id)
        .toList();
    final areAllVisibleSelected = screenState.areAllSelected(visibleWishIds);

    return Column(
      children: [
        // La carte de sélection prend la place des stats, qui restent dans
        // l'arbre (invisibles, sans touche ni focus) pour lui donner
        // exactement leur hauteur
        Stack(
          children: [
            IgnorePointer(
              ignoring: screenState.isSelectionMode,
              child: ExcludeFocus(
                excluding: screenState.isSelectionMode,
                child: AnimatedOpacity(
                  duration: _cardsFadeDuration,
                  opacity: screenState.isSelectionMode ? 0 : 1,
                  child: WishlistStatsSection(
                    statCardSelected: screenState.statCardSelected,
                    nbWishsTotal: wishs.length,
                    nbWishsPending: nbWishsPending,
                    nbWishsBooked: nbWishsBooked,
                    isWishsBookedHidden: isWishsBookedHidden,
                    onTapStatCard: notifier.selectStatCard,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: WishlistStatsSection.padding,
                child: AnimatedSwitcher(
                  duration: _cardsFadeDuration,
                  layoutBuilder: inertSwitcherLayout(fit: StackFit.expand),
                  child: screenState.isSelectionMode
                      ? WishlistSelectionCard(
                          selectedCount: screenState.selectedWishIds.length,
                          areAllSelected: areAllVisibleSelected,
                          onToggleSelectAll: visibleWishIds.isEmpty
                              ? null
                              : () => areAllVisibleSelected
                                  ? notifier.deselectAll(visibleWishIds)
                                  : notifier.selectAll(visibleWishIds),
                          onExit: notifier.exitSelectionMode,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        WishlistSearchBar(
          searchController: notifier.searchController,
          searchFocusNode: notifier.searchFocusNode,
          searchQuery: screenState.searchQuery,
          wishSort: screenState.wishSort,
          onSortChanged: notifier.updateSort,
          onClearFocus: () => FocusScope.of(context).requestFocus(FocusNode()),
        ),
        Expanded(
          child: PageView(
            physics: const ClampingScrollPhysics(),
            controller: notifier.pageController,
            onPageChanged: notifier.onPageChanged,
            children: [
              _buildWishsTab(
                context,
                ref,
                wishlist: wishlist,
                wishs: wishsPending,
                shouldDisplay: nbWishsPending > 0,
                cardType: WishlistStatsCardType.pending,
                isWishsBookedHidden: isWishsBookedHidden,
                screenState: screenState,
                notifier: notifier,
                quantityOverrideMap: pendingQuantityOverrides.unlockView,
              ),
              _buildWishsTab(
                context,
                ref,
                wishlist: wishlist,
                wishs: wishsBooked,
                shouldDisplay: nbWishsBooked > 0 && !isWishsBookedHidden,
                cardType: WishlistStatsCardType.booked,
                isWishsBookedHidden: isWishsBookedHidden,
                screenState: screenState,
                notifier: notifier,
                quantityOverrideMap: bookedQuantityOverrides.isNotEmpty
                    ? bookedQuantityOverrides.unlockView
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
