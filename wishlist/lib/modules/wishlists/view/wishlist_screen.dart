import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wishlist/app/config/deeplink_config.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/completed_wishes/view/widgets/wishes_completed_snack_bar.dart';
import 'package:wishlist/modules/wishlists/infra/wishlist_screen_data_realtime_provider.dart';
import 'package:wishlist/modules/wishlists/view/widgets/move_wishes_dialog.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_app_bar.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_floating_actions.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_screen_body.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/shared/infra/completed_wish_mutations_provider.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/utils/get_wishlist_theme.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/utils/retry_providers_extension.dart';
import 'package:wishlist/shared/widgets/dialogs/completion_date_dialog.dart';
import 'package:wishlist/shared/widgets/dialogs/confirm_dialog.dart';
import 'package:wishlist/shared/widgets/dialogs/quantity_selection_dialog.dart';
import 'package:wishlist/shared/widgets/error_page_with_back.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({
    super.key,
    required this.wishlistId,
  });

  final int wishlistId;

  Future<void> _deleteSelectedWishs(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final notifier =
        ref.read(wishlistScreenNotifierProvider(wishlistId).notifier);
    final count = ref
        .read(wishlistScreenNotifierProvider(wishlistId))
        .selectedWishIds
        .length;
    // La sélection a pu se vider entre-temps (wishs supprimés ailleurs)
    if (count == 0) {
      return;
    }
    final l10n = context.l10n;

    final explanation = count == 1
        ? l10n.deleteSelectedWishConfirmation
        : l10n.deleteSelectedWishesConfirmation(count);

    await showConfirmDialog(
      context,
      title: l10n.deleteSelectedWishes,
      explanation: explanation,
      onConfirm: () async {
        try {
          // La sélection a pu changer pendant la confirmation (wishs
          // supprimés ailleurs) : le message compte les wishs traités
          final deleted = await notifier.deleteSelectedWishs();
          if (deleted > 0 && context.mounted) {
            showAppSnackBar(
              context,
              deleted == 1
                  ? l10n.deleteWishSuccess
                  : l10n.wishesDeleted(deleted),
              type: SnackBarType.success,
            );
          }
        } catch (e) {
          if (context.mounted) {
            showGenericError(context, error: e);
          }
        }
      },
    );
  }

  Future<void> _moveSelectedWishs(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final notifier =
        ref.read(wishlistScreenNotifierProvider(wishlistId).notifier);
    final count = ref
        .read(wishlistScreenNotifierProvider(wishlistId))
        .selectedWishIds
        .length;
    // La sélection a pu se vider entre-temps (wishs supprimés ailleurs)
    if (count == 0) {
      return;
    }
    final l10n = context.l10n;

    await showMoveWishesDialog(
      context,
      currentWishlistId: wishlistId,
      wishCount: count,
      onConfirm: (targetWishlistId) async {
        try {
          // Comme pour la suppression : les wishs traités, pas ceux annoncés
          final moved = await notifier.moveSelectedWishs(targetWishlistId);
          if (moved > 0 && context.mounted) {
            showAppSnackBar(
              context,
              l10n.wishesMoved(moved),
              type: SnackBarType.success,
            );
          }
        } catch (e) {
          if (context.mounted) {
            showGenericError(context, error: e);
          }
        }
      },
    );
  }

  Future<void> _completeSelectedWishs(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final notifier =
        ref.read(wishlistScreenNotifierProvider(wishlistId).notifier);
    // Lu avant et après le dialog de la date : les wishs ont pu changer
    // pendant qu'il était ouvert
    IList<Wish> readWishs() =>
        ref
            .read(wishlistScreenDataRealtimeProvider(wishlistId))
            .valueOrNull
            ?.wishs ??
        const IListConst([]);
    final selectedIds =
        ref.read(wishlistScreenNotifierProvider(wishlistId)).selectedWishIds;
    final selectedWishs =
        readWishs().where((w) => selectedIds.contains(w.id)).toList();
    // La sélection a pu se vider entre-temps (wishs supprimés ailleurs)
    if (selectedWishs.isEmpty) {
      return;
    }
    final l10n = context.l10n;

    // Un seul jour pour toute la sélection, demandé avant les quantités
    final count = selectedWishs.length;
    final completedAt = await showCompletionDateDialog(
      context,
      title: l10n.completionDateDialogTitle(count),
      explanation: l10n.completionDateDialogExplanation(count),
      wishName: count == 1 ? selectedWishs.single.name : null,
      confirmButtonLabel: selectedWishs.any((w) => w.quantity > 1)
          ? l10n.continueButton
          : l10n.completeButton,
    );
    if (completedAt == null || !context.mounted) {
      return;
    }

    final wishs = readWishs();
    // Mes réceptions : celles que l'écran écoute (la wishlist est à moi), lues
    // après le dialog comme les wishs
    final currentUserId = ref.read(currentUserIdProvider);
    final completedWishs = currentUserId == null
        ? null
        : ref
            .read(completedWishesByUserRealtimeProvider(currentUserId))
            .valueOrNull;

    var completedCount = 0;
    // Chaque wish reçu quitte la liste pendant la boucle : runOnSelection
    // garde le mode sélection ouvert jusqu'à la fin
    await notifier.runOnSelection((selectedIds) async {
      for (final wishId in selectedIds) {
        if (!context.mounted) {
          break;
        }
        final matching = wishs.where((w) => w.id == wishId);
        if (matching.isEmpty) {
          continue;
        }
        final wish = matching.first;

        final completedEntry =
            completedWishs?.where((c) => c.wish.id == wish.id).firstOrNull;
        final alreadyCompletedQuantity = completedEntry?.quantity ?? 0;

        if (wish.quantity > 1) {
          final confirmed = await showCompleteWishQuantityDialog(
            context,
            ref,
            wish: wish,
            alreadyCompletedQuantity: alreadyCompletedQuantity,
            completedAt: completedAt,
          );
          if (confirmed) {
            completedCount++;
          }
        } else {
          try {
            await ref
                .read(completedWishMutationsProvider.notifier)
                .markAsCompleted(wish, completedAt: completedAt);
            completedCount++;
          } catch (e) {
            if (context.mounted) {
              showGenericError(context, error: e);
            }
          }
        }
      }
    });

    if (completedCount > 0 && context.mounted) {
      showWishesCompletedSnackBar(context, completedCount);
    }
  }

  Future<void> _shareWishlist(
    BuildContext context,
    Wishlist wishlist,
    Rect origin,
  ) async {
    final shareLink =
        DeeplinkConfig.buildWishlistShareUri(wishlistId: wishlist.id)
            .toString();

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${wishlist.name}\n$shareLink',
          // Required on iPad, where the sheet is a popover: without it the
          // share fails
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        showGenericError(context, error: e);
      }
    }
  }

  void _onWishlistDeleted(BuildContext context) {
    // Quand le propriétaire supprime la wishlist depuis cet écran, le dialog
    // de confirmation est au premier plan et gère lui-même la navigation
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }

    showAppSnackBar(
      context,
      context.l10n.wishlistDeleted,
      type: SnackBarType.error,
    );

    if (context.canPop()) {
      context.pop();
    } else {
      HomeRoute().go(context);
    }
  }

  /// The streams the screen data is built from. Retrying must re-open them:
  /// invalidating [wishlistScreenDataRealtimeProvider] alone would keep their
  /// errors.
  List<AutoDisposeStreamProvider<Object?>> _sourceProviders(WidgetRef ref) {
    final ownerId =
        ref.read(watchWishlistByIdProvider(wishlistId)).valueOrNull?.idOwner;

    return [
      watchWishlistByIdProvider(wishlistId),
      watchWishsFromWishlistProvider(wishlistId),
      if (ownerId != null) completedWishesByUserRealtimeProvider(ownerId),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(watchWishlistByIdProvider(wishlistId), (_, next) {
      if (next case AsyncData(value: null)) {
        _onWishlistDeleted(context);
      }
    });

    // Seuls le mode sélection et l'action en cours sont utilisés ici : la
    // recherche, le tri et la sélection sont watchés par le body et les
    // actions flottantes, sinon tout l'écran se reconstruirait à chaque frappe
    final (isSelectionMode, isSelectionActionRunning) = ref.watch(
      wishlistScreenNotifierProvider(wishlistId).select(
        (state) => (state.isSelectionMode, state.isSelectionActionRunning),
      ),
    );
    final notifier =
        ref.read(wishlistScreenNotifierProvider(wishlistId).notifier);
    final isWishlistDeleted = ref.watch(
      watchWishlistByIdProvider(wishlistId).select(
        (wishlist) => switch (wishlist) {
          AsyncData(value: null) => true,
          _ => false,
        },
      ),
    );
    final wishlistScreenData =
        ref.watch(wishlistScreenDataRealtimeProvider(wishlistId));
    // The screen data rebuilds a fresh AsyncError while its sources reload,
    // so a retry is only visible on the failed sources themselves
    final isRetrying = ref.isRetryingAny(_sourceProviders(ref));

    if (isWishlistDeleted) {
      return ErrorPageWithBack.unavailable(
        message: context.l10n.wishlistDeleted,
      );
    }

    return wishlistScreenData.when(
      data: (data) {
        final wishlist = data.wishlist;
        final wishlistTheme = getWishlistTheme(context, wishlist);
        // read, not watch: the screen outlives the session for a few frames
        // until the router redirects, and must not turn into a visitor view
        // of one's own wishlist when the id becomes null.
        final isMyWishlist =
            wishlist.idOwner == ref.read(currentUserIdProvider);
        final canShareWishlist =
            wishlist.visibility == WishlistVisibility.public;

        return AnimatedTheme(
          data: wishlistTheme,
          child: Builder(
            builder: (context) {
              return PopScope(
                canPop: !isSelectionMode,
                onPopInvokedWithResult: (didPop, result) {
                  // Le retour fait comme la croix, inerte pendant une action
                  // sur la sélection : il attend la fin de l'action
                  if (!didPop && isSelectionMode && !isSelectionActionRunning) {
                    notifier.exitSelectionMode();
                  }
                },
                child: Scaffold(
                  resizeToAvoidBottomInset: false,
                  appBar: WishlistAppBar(
                    title: wishlist.name,
                    wishlistTheme: wishlistTheme,
                    isMyWishlist: isMyWishlist,
                    canShareWishlist: canShareWishlist,
                    onShare: (origin) => _shareWishlist(
                      context,
                      wishlist,
                      origin,
                    ),
                    onSettings: () => WishlistSettingsRoute(
                      wishlistId: wishlist.id,
                    ).push(context),
                  ),
                  body: SafeArea(
                    // Le bas est géré par les enfants pour que le fond gris
                    // de la liste aille jusqu'au bord de l'écran
                    bottom: false,
                    child: Stack(
                      children: [
                        WishlistScreenBody(
                          wishlistId: wishlistId,
                          wishlistScreenData: data,
                          isMyWishlist: isMyWishlist,
                        ),
                        if (isMyWishlist)
                          WishlistFloatingActions(
                            wishlistId: wishlistId,
                            onAdd: () => CreateWishRoute(
                              wishlistId: wishlist.id,
                            ).push(context),
                            onDelete: () => _deleteSelectedWishs(context, ref),
                            onMove: () => _moveSelectedWishs(context, ref),
                            onComplete: () =>
                                _completeSelectedWishs(context, ref),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => ErrorPageWithBack.failure(
        error: error,
        onRetry: () => ref.retryFailed(_sourceProviders(ref)),
        isRetrying: isRetrying,
      ),
    );
  }
}
