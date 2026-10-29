import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/home/view/widgets/home_empty_wishlists.dart';
import 'package:wishlist/modules/home/view/widgets/home_profile_header.dart';
import 'package:wishlist/modules/home/view/widgets/home_received_wishes_row.dart';
import 'package:wishlist/modules/home/view/widgets/home_wishlists_error.dart';
import 'package:wishlist/shared/infra/received_wishes_summary_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
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
      // The header and the received wishes row hide their errors (they never
      // block the page): a refresh is what brings them back
      ref
        ..invalidate(watchCurrentUserProfileProvider)
        ..invalidate(receivedWishesSummaryProvider)
        ..invalidate(wishlistsRealtimeProvider);

      // Attendre que le nouveau stream soit initialisé. A failure is shown in
      // place of the grid: it must not escape from the refresh.
      try {
        await ref.read(wishlistsRealtimeProvider.future);
      } catch (_) {}
    }

    // Loading and error only replace the grid: the header and the received
    // wishes row stay, so the profile and the received wishes remain reachable
    // when the wishlists do not load.
    final wishlistsSliver = wishlists.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => SliverToBoxAdapter(
        child: HomeWishlistsError(
          error: error,
          onRetry: () => ref.retryFailed([wishlistsRealtimeProvider]),
          isRetrying: ref.isRetryingAny([wishlistsRealtimeProvider]),
        ),
      ),
      data: (data) => data.isEmpty
          ? const SliverToBoxAdapter(child: HomeEmptyWishlists())
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              sliver: SliverWishlistsGrid(wishlists: data),
            ),
    );

    return Scaffold(
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
              wishlistsSliver,
              SliverToBoxAdapter(
                child: SizedBox(height: NavBarPadding.of(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
