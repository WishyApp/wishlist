import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/wishs/view/widgets/consult_wish_back_button.dart';
import 'package:wishlist/modules/wishs/view/widgets/consult_wish_image.dart';
import 'package:wishlist/modules/wishs/view/widgets/consult_wish_info_container.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/providers/wishlist_theme_provider.dart';

enum WishQuantityDisplay { total, pending, booked, myBooked, completed }

class ConsultWishScreen extends ConsumerStatefulWidget {
  const ConsultWishScreen({
    super.key,
    required this.wishIds,
    required this.initialIndex,
    this.showActions = true,
    this.quantityDisplay = WishQuantityDisplay.total,
  });

  final List<int> wishIds;
  final int initialIndex;
  final bool showActions;
  final WishQuantityDisplay quantityDisplay;

  @override
  ConsumerState<ConsultWishScreen> createState() => _ConsultWishScreenState();
}

class _ConsultWishScreenState extends ConsumerState<ConsultWishScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _buildPageView(l10n);
  }

  Widget _buildPageView(AppLocalizations l10n) {
    final wishIds = widget.wishIds;

    return PageView.builder(
      controller: _pageController,
      itemCount: wishIds.length,
      itemBuilder: (context, index) {
        final wishId = wishIds[index];
        final wish = ref.watch(watchWishByIdProvider(wishId));
        return _buildSingleWish(wish, l10n);
      },
    );
  }

  Widget _buildSingleWish(
    AsyncValue<Wish> wish,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      backgroundColor: AppColors.gainsboro,
      body: wish.when(
        data: (wishData) {
          final quantityToDisplay = _quantityToDisplay(wishData);
          // Le droit d'édition vient du propriétaire de la wishlist, jamais
          // de l'URL (deep link).
          final wishlistAsync =
              ref.watch(watchWishlistByIdProvider(wishData.wishlistId));
          final ownerId = wishlistAsync.valueOrNull?.idOwner;
          final currentUserId =
              ref.read(userServiceProvider).getCurrentUserId();
          final isMyWishlist = ownerId != null && ownerId == currentUserId;
          // Tant que le propriétaire n'est pas connu, on masque les actions
          // pour ne pas afficher brièvement celles d'un invité au propriétaire.
          final isOwnershipKnown =
              wishlistAsync.hasValue || wishlistAsync.hasError;
          final wishlistThemeAsync =
              ref.watch(wishlistThemeProvider(wishData.wishlistId));

          return wishlistThemeAsync.when(
            data: (wishlistTheme) {
              final descriptionText = wishData.description.isNotEmpty
                  ? wishData.description
                  : l10n.noDescription;

              return AnimatedTheme(
                data: wishlistTheme,
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            const ConsultWishBackButton(),
                            const Gap(16),
                            ConsultWishImage(
                              wish: wishData,
                              quantityToDisplay: quantityToDisplay,
                            ),
                            const Gap(32),
                            ConsultWishInfoContainer(
                              wish: wishData,
                              descriptionText: descriptionText,
                              isMyWishlist: isMyWishlist,
                              showActions:
                                  widget.showActions && isOwnershipKnown,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          );
        },
        error: (error, stackTrace) => const SizedBox.shrink(),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  int _quantityToDisplay(Wish wish) {
    final completedQuantity = ref
            .watch(completedWishesRealtimeProvider)
            .valueOrNull
            ?.where((item) => item.wish.id == wish.id)
            .firstOrNull
            ?.quantity ??
        0;

    switch (widget.quantityDisplay) {
      case WishQuantityDisplay.total:
        return wish.quantity;
      case WishQuantityDisplay.pending:
        return (wish.quantity - wish.totalBookedQuantity - completedQuantity)
            .clamp(0, wish.quantity);
      case WishQuantityDisplay.booked:
        return (wish.totalBookedQuantity - completedQuantity).clamp(
          0,
          wish.totalBookedQuantity,
        );
      case WishQuantityDisplay.myBooked:
        final currentUserId = ref.read(userServiceProvider).getCurrentUserId();
        return wish.takenByUser
                .where((reservation) => reservation.userId == currentUserId)
                .firstOrNull
                ?.quantity ??
            0;
      case WishQuantityDisplay.completed:
        return completedQuantity;
    }
  }
}
