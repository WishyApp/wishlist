import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/wishlists/infra/wishlist_screen_data_realtime_provider.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_search_bar.dart';
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

class WishlistScreenBody extends ConsumerWidget {
  const WishlistScreenBody({
    super.key,
    required this.wishlistId,
    required this.wishlistScreenData,
    required this.isMyWishlist,
  });

  final int wishlistId;
  final WishlistScreenData wishlistScreenData;
  final bool isMyWishlist;

  void _onTapWish(
    BuildContext context,
    WidgetRef ref,
    Wish wish, {
    required bool isMyWishlist,
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
        required isMyWishlist,
        required wishsToDisplay,
        cardType,
      }) =>
          _onTapWish(
        context,
        ref,
        wish,
        isMyWishlist: isMyWishlist,
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
    final bookedQuantityOverrides = display.bookedQuantityOverrides;
    final isWishsBookedHidden = !wishlist.canOwnerSeeTakenWish && isMyWishlist;
    final wishsPending = isWishsBookedHidden ? wishs : display.available;

    final nbWishsPending = wishsPending.length;
    final nbWishsBooked = wishsBooked.length;

    return Column(
      children: [
        WishlistStatsSection(
          statCardSelected: screenState.statCardSelected,
          nbWishsTotal: wishs.length,
          nbWishsPending: nbWishsPending,
          nbWishsBooked: nbWishsBooked,
          isWishsBookedHidden: isWishsBookedHidden,
          onTapStatCard: notifier.selectStatCard,
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
