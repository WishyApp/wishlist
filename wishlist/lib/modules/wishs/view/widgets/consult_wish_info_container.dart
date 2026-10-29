import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/completed_wishes/view/widgets/wishes_completed_snack_bar.dart';
import 'package:wishlist/modules/wishs/view/widgets/consult_box_shadow.dart';
import 'package:wishlist/modules/wishs/view/widgets/scrollable_content_with_indicator.dart';
import 'package:wishlist/shared/infra/completed_wish_mutations_provider.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/wish_taken_by_user_service.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/utils/formatters.dart';
import 'package:wishlist/shared/utils/link_utils.dart';
import 'package:wishlist/shared/widgets/dialogs/completion_date_dialog.dart';
import 'package:wishlist/shared/widgets/dialogs/confirm_dialog.dart';
import 'package:wishlist/shared/widgets/dialogs/quantity_selection_dialog.dart';

class ConsultWishInfoContainer extends ConsumerWidget {
  const ConsultWishInfoContainer({
    super.key,
    required this.wish,
    required this.descriptionText,
    required this.ownerReceivedQuantity,
    this.isMyWishlist = false,
    this.showActions = true,
  });

  final Wish wish;
  final String descriptionText;
  final bool isMyWishlist;
  final bool showActions;

  /// Quantité de ce wish déjà reçue par le propriétaire de la wishlist, ou
  /// null tant que ses réceptions ne sont pas connues : elle vaudrait 0 à
  /// tort, donc les actions qui en dépendent (offrir, modifier ma
  /// réservation, marquer comme reçu) sont masquées.
  final int? ownerReceivedQuantity;

  Future<void> _onOpenLinkTap(BuildContext context, Uri linkUri) async {
    var isLaunched = false;
    try {
      isLaunched =
          await launchUrl(linkUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      isLaunched = false;
    }

    if (!isLaunched && context.mounted) {
      showAppSnackBar(
        context,
        context.l10n.linkNotValid,
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _onGiveItTap(
    BuildContext context,
    WidgetRef ref, {
    required int receivedQuantity,
  }) async {
    // Same source as build(): null while signed out (the screen is leaving),
    // where nothing can be booked.
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      return;
    }
    final isWishTakenByMe = wish.takenByUser.any(
      (element) => element.userId == currentUserId,
    );

    var currentQuantity = 0;
    if (isWishTakenByMe) {
      final userReservation = wish.takenByUser.firstWhere(
        (element) => element.userId == currentUserId,
      );
      currentQuantity = userReservation.quantity;
    }

    // Si l'utilisateur a déjà réservé OU si quantité disponible > 1,
    // afficher le dialog de sélection
    final bookableQuantity =
        wish.bookableQuantity(receivedQuantity: receivedQuantity);
    if (isWishTakenByMe || bookableQuantity > 1) {
      await showQuantitySelectionDialog(
        context,
        ref,
        wish: wish,
        initialQuantity: isWishTakenByMe ? currentQuantity : 1,
        isModifying: isWishTakenByMe,
        receivedQuantity: receivedQuantity,
      );
      return;
    }

    // Si quantité disponible = 1 et pas encore réservé, réserver directement
    try {
      await ref.read(wishTakenByUserServiceProvider).wishTakenByUser(
            wish,
            quantity: 1,
          );

      if (context.mounted) {
        context.pop();
        showAppSnackBar(
          context,
          context.l10n.wishReservedSuccess,
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showGenericError(context, error: e);
      }
    }
  }

  Future<void> _onMarkAsCompletedTap(
    BuildContext context,
    WidgetRef ref, {
    required int completedQuantity,
  }) async {
    final l10n = context.l10n;
    final needsQuantity = wish.quantity > 1;

    // Sans quantité à choisir, le dialog de la date complète le wish
    final completedAt = await showCompletionDateDialog(
      context,
      title: l10n.completionDateDialogTitle(1),
      explanation: l10n.completionDateDialogExplanation(1),
      confirmButtonLabel:
          needsQuantity ? l10n.continueButton : l10n.completeButton,
      onConfirm: needsQuantity
          ? null
          : (completedAt) => ref
              .read(completedWishMutationsProvider.notifier)
              .markAsCompleted(wish, completedAt: completedAt),
    );
    if (completedAt == null || !context.mounted) {
      return;
    }

    if (needsQuantity) {
      final confirmed = await showCompleteWishQuantityDialog(
        context,
        ref,
        wish: wish,
        alreadyCompletedQuantity: completedQuantity,
        completedAt: completedAt,
      );
      if (!confirmed || !context.mounted) {
        return;
      }
    }

    showWishesCompletedSnackBar(context, 1);
    context.pop();
  }

  Future<void> _onCancelGiveItTap(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;

    await showConfirmDialog(
      context,
      title: l10n.cancelBookingDialogTitle,
      explanation: l10n.cancelBookingDialogExplanation,
      onConfirm: () async {
        try {
          await ref.read(wishTakenByUserServiceProvider).cancelWishTaken(wish);

          if (context.mounted) {
            context.pop();
          }
        } catch (e) {
          if (context.mounted) {
            showGenericError(context, error: e);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final linkUri = parseWebLink(wish.linkUrl);

    // Null while signed out (the screen is leaving): nothing is mine.
    final currentUserId = ref.watch(currentUserIdProvider);

    final isWishTakenByMe = wish.takenByUser.any(
      (element) => element.userId == currentUserId,
    );

    final receivedQuantity = ownerReceivedQuantity;
    final areReceiptsKnown = receivedQuantity != null;
    final isFullyCompleted = (receivedQuantity ?? 0) >= wish.quantity;
    final canMarkAsCompleted =
        isMyWishlist && areReceiptsKnown && !isFullyCompleted;

    final hasQuantity = wish.quantity > 1;
    // La quantité déjà reçue par le propriétaire consomme d'abord les
    // réservations, le serveur refuse une réservation au-delà de
    // quantité - max(réservé, reçu).
    final hasAvailableQuantity =
        wish.bookableQuantity(receivedQuantity: receivedQuantity ?? 0) > 0;

    // Logique d'affichage des boutons basée sur la réservation de l'utilisateur
    final shouldShowGiveItButton =
        areReceiptsKnown && !isWishTakenByMe && hasAvailableQuantity;
    final shouldShowModifyButton =
        areReceiptsKnown && isWishTakenByMe && hasQuantity;
    final shouldShowCancelButton = isWishTakenByMe;

    final price = wish.price;

    const spacing = 12.0;
    const padding = 16.0;

    // The sheet extends under the bottom system inset (home indicator,
    // navigation bar) so its background reaches the screen edge, while its
    // content stays above it.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    late final bool showPrimaryAction;
    late final VoidCallback? primaryActionOnPressed;
    late final String primaryActionText;

    if (isMyWishlist) {
      showPrimaryAction = true;
      primaryActionOnPressed = () =>
          EditWishRoute(wishlistId: wish.wishlistId, wishId: wish.id)
              .push(context);
      primaryActionText = l10n.editButton;
    } else if (shouldShowGiveItButton || shouldShowModifyButton) {
      showPrimaryAction = true;
      primaryActionOnPressed = () => _onGiveItTap(
            context,
            ref,
            receivedQuantity: receivedQuantity,
          );
      primaryActionText =
          shouldShowGiveItButton ? l10n.iWantToGiveIt : l10n.modifyBooking;
    } else {
      showPrimaryAction = false;
      primaryActionOnPressed = null;
      primaryActionText = '';
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height / 1.8 + bottomInset,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          boxShadow: [consultBoxShadow],
        ),
        child: Container(
          padding: const EdgeInsets.all(padding).copyWith(
            bottom: padding + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      wish.name,
                      style: AppTextStyles.titleSmall,
                    ),
                  ),
                  const Gap(8),
                  if (linkUri != null)
                    IconButton(
                      onPressed: () => _onOpenLinkTap(context, linkUri),
                      icon: const Icon(
                        Icons.open_in_new,
                        color: AppColors.makara,
                        size: 32,
                      ),
                      iconSize: 32,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      wish.isFavourite ? Icons.favorite : Icons.favorite_border,
                      color: wish.isFavourite
                          ? AppColors.favorite
                          : AppColors.makara,
                      size: 32,
                    ),
                  ),
                ],
              ),
              const Gap(4),
              if (price != null)
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    Formatters.currency(price),
                    style: AppTextStyles.small,
                  ),
                ),
              const Gap(spacing),
              SizedBox(
                width: double.infinity,
                child: Text(
                  l10n.wishDescriptionLabel,
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Gap(spacing),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gainsboro,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ScrollableContentWithIndicator(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SelectableText(
                            descriptionText,
                            style: AppTextStyles.smaller,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showActions) ...[
                const Gap(spacing * 3),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: spacing,
                  children: [
                    if (!isMyWishlist && shouldShowCancelButton)
                      SecondaryButton(
                        style: BaseButtonStyle.medium,
                        onPressed: () => _onCancelGiveItTap(context, ref),
                        text: l10n.cancelBooking,
                        isStretched: true,
                      ),
                    if (canMarkAsCompleted)
                      SecondaryButton(
                        style: BaseButtonStyle.medium,
                        onPressed: () => _onMarkAsCompletedTap(
                          context,
                          ref,
                          completedQuantity: receivedQuantity,
                        ),
                        text: l10n.markWishAsCompleted,
                        isStretched: true,
                      ),
                    if (showPrimaryAction)
                      PrimaryButton(
                        style: BaseButtonStyle.medium,
                        onPressed: primaryActionOnPressed,
                        text: primaryActionText,
                        isStretched: true,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
