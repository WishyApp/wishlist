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
import 'package:wishlist/shared/utils/retry_providers_extension.dart';

enum WishQuantityDisplay { total, pending, booked, myBooked, completed }

class ConsultWishScreen extends ConsumerStatefulWidget {
  const ConsultWishScreen({
    super.key,
    required this.wishIds,
    required this.initialIndex,
    this.showActions = true,
    this.quantityDisplay = WishQuantityDisplay.total,
    this.completedByUserId,
  });

  final List<int> wishIds;
  final int initialIndex;
  final bool showActions;
  final WishQuantityDisplay quantityDisplay;

  /// With [WishQuantityDisplay.completed], the user whose receipts give the
  /// quantity (a friend's completed wishes): the current user's when null.
  /// Read directly rather than through the owner of the wishlist, which is
  /// unknown once the wishlist is archived.
  final String? completedByUserId;

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
        // Les réceptions qui comptent sont celles du propriétaire de la
        // wishlist (les miennes si elle est à moi, sinon les siennes) : le
        // même provider dans les deux cas.
        final ownerReceiptsAsync = ownerId == null
            ? null
            : ref.watch(completedWishesByUserRealtimeProvider(ownerId));
        // Tant que les réceptions ne sont pas connues (chargement, ou
        // échec du premier chargement), la quantité reçue vaudrait 0 à tort :
        // un wish déjà reçu afficherait « Je veux l'offrir ». D'où null =
        // inconnue : seules les actions qui en dépendent sont masquées (pas
        // Modifier ni l'annulation d'une réservation). Même logique que
        // isOwnershipKnown ci-dessous (hasValue, pas hasError).
        final ownerReceipts = ownerReceiptsAsync?.valueOrNull;
        final ownerReceivedQuantity = ownerReceipts == null
            ? null
            : ownerReceipts
                    .where((item) => item.wish.id == wishData.id)
                    .firstOrNull
                    ?.quantity ??
                0;
        final quantityToDisplay = _quantityToDisplay(
          wishData,
          ownerReceivedQuantity: ownerReceivedQuantity,
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
                              ownerReceivedQuantity: ownerReceivedQuantity,
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
            onRetry: () =>
                ref.retryFailed(_sourceProviders(wishId, wishData.wishlistId)),
            isRetrying: ref
                .isRetryingAny(_sourceProviders(wishId, wishData.wishlistId)),
          ),
        );
      },
      error: (error, stackTrace) => WishLoadError(
        error: error,
        onRetry: () => ref.retryFailed(_sourceProviders(wishId, null)),
        isRetrying: ref.isRetryingAny(_sourceProviders(wishId, null)),
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
    required int? ownerReceivedQuantity,
  }) {
    switch (widget.quantityDisplay) {
      case WishQuantityDisplay.total:
        return wish.quantity;
      case WishQuantityDisplay.pending:
        // Réceptions inconnues : pas de badge plutôt qu'une quantité fausse.
        if (ownerReceivedQuantity == null) {
          return 0;
        }
        return wish.pendingQuantity(receivedQuantity: ownerReceivedQuantity);
      case WishQuantityDisplay.booked:
        if (ownerReceivedQuantity == null) {
          return 0;
        }
        return wish.remainingBookedQuantity(
          receivedQuantity: ownerReceivedQuantity,
        );
      case WishQuantityDisplay.myBooked:
        final currentUserId = ref.watch(currentUserIdProvider);
        return wish.takenByUser
                .where((reservation) => reservation.userId == currentUserId)
                .firstOrNull
                ?.quantity ??
            0;
      case WishQuantityDisplay.completed:
        // Les réceptions de la liste d'où l'on vient (les miennes, ou celles
        // d'un ami), pas celles du propriétaire de la wishlist : une wishlist
        // archivée ne donne plus son propriétaire.
        final completedByUserId = widget.completedByUserId;
        final completedWishes = ref.watch(
          completedByUserId == null
              ? completedWishesRealtimeProvider
              : completedWishesByUserRealtimeProvider(completedByUserId),
        );
        if (!completedWishes.hasValue) {
          return 0;
        }
        return completedWishes.requireValue
                .where((item) => item.wish.id == wish.id)
                .firstOrNull
                ?.quantity ??
            0;
    }
  }
}
