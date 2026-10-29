import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/l10n/l10n.dart';
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
import 'package:wishlist/shared/widgets/wishlists_grid.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final wishlists = ref.watch(wishlistsRealtimeProvider);

    Future<void> refreshWishlists() async {
      ref.invalidate(wishlistsRealtimeProvider);

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
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HomeProfileHeader(),
                  const HomeReceivedWishesRow(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Text(
                      l10n.homeMyWishlists,
                      style: AppTextStyles.small.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.makara,
                      ),
                    ),
                  ),
                  if (data.isEmpty)
                    const HomeEmptyWishlists()
                  else
                    WishlistsGrid(
                      wishlists: data,
                      isReorderable: true,
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(20),
                    ),
                  SizedBox(height: NavBarPadding.of(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
