import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/modules/home/view/widgets/cards/home_card_stack.dart';
import 'package:wishlist/modules/home/view/widgets/home_empty_wishlists.dart';
import 'package:wishlist/modules/home/view/widgets/home_profile_header.dart';
import 'package:wishlist/modules/home/view/widgets/home_received_wishes_row.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/page_layout_error/page_layout_error.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/app_refresh_indicator.dart';
import 'package:wishlist/shared/theme/widgets/app_scaffold.dart';
import 'package:wishlist/shared/utils/retry_providers_extension.dart';
import 'package:wishlist/shared/widgets/sliver_wishlists_grid.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final wishlists = ref.watch(wishlistsRealtimeProvider);

    Future<void> refreshWishlists() async {
      ref
        ..invalidate(wishlistsRealtimeProvider)
        // Not awaited: the pile keeps its cards while it reloads
        ..invalidate(homeCardsProvider);

      // Attendre que le nouveau stream soit initialisé
      await ref.read(wishlistsRealtimeProvider.future);
    }

    return wishlists.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => PageLayoutError(
        error: error,
        onRetry: () => ref.retryFailed([wishlistsRealtimeProvider]),
        isRetrying: ref.isRetryingAny([wishlistsRealtimeProvider]),
        appBarTitle: l10n.wishlistsScreenTitle,
      ),
      data: (data) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: AppRefreshIndicator(
            onRefresh: refreshWishlists,
            // The page is the nearest scrollable of the grid, so the drag
            // autoscroll of a wishlist scrolls it.
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: HomeProfileHeader()),
                const SliverToBoxAdapter(child: HomeCardsSlot()),
                const SliverToBoxAdapter(child: HomeReceivedWishesRow()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      l10n.homeMyWishlists,
                      style: AppTextStyles.small.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.makara,
                      ),
                    ),
                  ),
                ),
                if (data.isEmpty)
                  const SliverToBoxAdapter(child: HomeEmptyWishlists())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    sliver: SliverWishlistsGrid(wishlists: data),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(height: NavBarPadding.of(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
