import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/wishs/view/widgets/consult_wish_back_button.dart';
import 'package:wishlist/modules/wishs/view/widgets/consult_wish_image.dart';
import 'package:wishlist/modules/wishs/view/widgets/consult_wish_info_container.dart';
import 'package:wishlist/modules/wishs/view/widgets/wish_load_error.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
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
        return _buildSingleWish(wishId, wish, l10n);
      },
    );
  }

  /// Only re-opens the providers that failed: the healthy ones keep their data.
  Future<void> _retryLoading(int wishId, int? wishlistId) async {
    final failed = _sourceProviders(wishId, wishlistId)
        .where((provider) => ref.read(provider).hasError)
        .toList();

    failed.forEach(ref.invalidate);
    await Future.wait(failed.map((provider) => ref.read(provider.future)));
  }

  /// A failed provider reloads as a loading state that still holds its error.
  bool _isRetrying(int wishId, int? wishlistId) {
    return _sourceProviders(wishId, wishlistId).any(
      (provider) => ref.watch(
        provider.select((source) => source.hasError && source.isLoading),
      ),
    );
  }

  List<AutoDisposeStreamProvider<Object?>> _sourceProviders(
    int wishId,
    int? wishlistId,
  ) {
    return [
      watchWishByIdProvider(wishId),
      if (wishlistId != null) watchWishlistByIdProvider(wishlistId),
    ];
  }

  Widget _buildSingleWish(
    int wishId,
    AsyncValue<Wish> wish,
    AppLocalizations l10n,
  ) {
    return wish.when(
      data: (wishData) {
        // Le droit d'édition vient du propriétaire de la wishlist, jamais
        // de l'URL (deep link).
        final wishlistAsync =
            ref.watch(watchWishlistByIdProvider(wishData.wishlistId));
        final ownerId = wishlistAsync.valueOrNull?.idOwner;
        final currentUserId = ref.watch(currentUserIdProvider);
        final isMyWishlist = ownerId != null && ownerId == currentUserId;
        final quantityToDisplay = _quantityToDisplay(
          wishData,
          ownerId: ownerId,
          isMyWishlist: isMyWishlist,
        );
        // Tant que le propriétaire n'est pas connu, on masque les actions
        // pour ne pas afficher brièvement celles d'un invité au propriétaire.
        // hasValue (et non hasError) : si le premier chargement échoue,
        // le propriétaire reste inconnu et on ne montre pas les actions
        // d'un invité. Après un premier succès, Riverpod conserve la
        // valeur précédente lors d'une erreur de rechargement.
        final isOwnershipKnown = wishlistAsync.hasValue;
        final wishlistThemeAsync =
            ref.watch(wishlistThemeProvider(wishData.wishlistId));

        return wishlistThemeAsync.when(
          data: (wishlistTheme) {
            final descriptionText = wishData.description.isNotEmpty
                ? wishData.description
                : l10n.noDescription;

            return Scaffold(
              backgroundColor: AppColors.gainsboro,
              body: AnimatedTheme(
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
              ),
            );
          },
          loading: _loadingScaffold,
          error: (error, _) => WishLoadError(
            error: error,
            onRetry: () => _retryLoading(wishId, wishData.wishlistId),
            isRetrying: _isRetrying(wishId, wishData.wishlistId),
          ),
        );
      },
      error: (error, stackTrace) => WishLoadError(
        error: error,
        onRetry: () => _retryLoading(wishId, null),
        isRetrying: _isRetrying(wishId, null),
      ),
      loading: _loadingScaffold,
    );
  }

  Widget _loadingScaffold() {
    return Scaffold(
      backgroundColor: AppColors.gainsboro,
      appBar: AppBar(backgroundColor: AppColors.gainsboro),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  int _quantityToDisplay(
    Wish wish, {
    required String? ownerId,
    required bool isMyWishlist,
  }) {
    final completedQuantity = ref
            .watch(completedWishesRealtimeProvider)
            .valueOrNull
            ?.where((item) => item.wish.id == wish.id)
            .firstOrNull
            ?.quantity ??
        0;

    // Quantité reçue par le propriétaire de la wishlist (celle que compte le
    // serveur) : pour un ami, ce n'est pas la sienne.
    int ownerReceivedQuantity() {
      if (isMyWishlist) {
        return completedQuantity;
      }
      if (ownerId == null) {
        return 0;
      }
      return ref
              .watch(completedWishesByUserRealtimeProvider(ownerId))
              .valueOrNull
              ?.where((item) => item.wish.id == wish.id)
              .firstOrNull
              ?.quantity ??
          0;
    }

    switch (widget.quantityDisplay) {
      case WishQuantityDisplay.total:
        return wish.quantity;
      case WishQuantityDisplay.pending:
        return wish.pendingQuantity(receivedQuantity: ownerReceivedQuantity());
      case WishQuantityDisplay.booked:
        return (wish.totalBookedQuantity - ownerReceivedQuantity()).clamp(
          0,
          wish.totalBookedQuantity,
        );
      case WishQuantityDisplay.myBooked:
        final currentUserId = ref.watch(currentUserIdProvider);
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
