import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/completed_wishes/view/widgets/uncomplete_wish_bottom_sheet.dart';
import 'package:wishlist/shared/infra/completed_wish_mutations_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/widgets/app_bottom_sheet.dart';
import 'package:wishlist/shared/widgets/app_list_tile.dart';
import 'package:wishlist/shared/widgets/dialogs/completion_date_dialog.dart';
import 'package:wishlist/shared/widgets/dialogs/quantity_selection_dialog.dart';

enum _CompletedWishOption { modifyDate, modifyQuantity, uncomplete }

/// The actions on one of the current user's completed wishes: change its
/// completion date or quantity, or uncomplete it.
///
/// The picked action runs once the sheet is closed, from [context]: the
/// sheet's own context is gone by then.
Future<void> showCompletedWishOptionsBottomSheet(
  BuildContext context,
  WidgetRef ref,
  CompletedWishWithDetails item,
) async {
  _CompletedWishOption? picked;
  await showAppBottomSheet(
    context,
    expandToFillHeight: false,
    body: _CompletedWishOptions(
      item: item,
      onPicked: (option) => picked = option,
    ),
  );
  if (!context.mounted) {
    return;
  }

  switch (picked) {
    case null:
      return;
    case _CompletedWishOption.modifyDate:
      await _modifyCompletionDate(context, ref, item);
    case _CompletedWishOption.modifyQuantity:
      await _modifyCompletedQuantity(context, ref, item);
    case _CompletedWishOption.uncomplete:
      await showUncompleteWishBottomSheet(context, item);
  }
}

Future<void> _modifyCompletionDate(
  BuildContext context,
  WidgetRef ref,
  CompletedWishWithDetails item,
) async {
  final l10n = context.l10n;
  final completedAt = await showCompletionDateDialog(
    context,
    title: l10n.completionDateDialogTitle(1),
    explanation: l10n.completionDateDialogExplanation(1),
    wishName: item.wish.name,
    initialValue: item.completedAt,
    confirmButtonLabel: l10n.save,
  );
  // Saved as is: nothing to update
  if (completedAt == null || completedAt == item.completedAt) {
    return;
  }
  if (!context.mounted) {
    return;
  }

  try {
    await ref
        .read(completedWishMutationsProvider.notifier)
        .updateCompletionDate(
          wishId: item.wish.id,
          completedAt: completedAt,
        );
    if (context.mounted) {
      showAppSnackBar(context, l10n.updateSuccess, type: SnackBarType.success);
    }
  } catch (e) {
    if (context.mounted) {
      showGenericError(context, error: e);
    }
  }
}

Future<void> _modifyCompletedQuantity(
  BuildContext context,
  WidgetRef ref,
  CompletedWishWithDetails item,
) async {
  final confirmed = await showCompleteWishQuantityDialog(
    context,
    ref,
    wish: item.wish,
    initialQuantity: item.quantity,
    isModifying: true,
  );
  if (confirmed && context.mounted) {
    showAppSnackBar(
      context,
      context.l10n.updateSuccess,
      type: SnackBarType.success,
    );
  }
}

class _CompletedWishOptions extends StatelessWidget {
  const _CompletedWishOptions({required this.item, required this.onPicked});

  final CompletedWishWithDetails item;
  final ValueChanged<_CompletedWishOption> onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    void pick(_CompletedWishOption option) {
      onPicked(option);
      Navigator.pop(context);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            item.wish.name,
            style: AppTextStyles.medium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AppListTile(
          icon: Icons.event,
          title: l10n.modifyCompletionDate,
          onTap: () => pick(_CompletedWishOption.modifyDate),
        ),
        if (item.wish.quantity > 1)
          AppListTile(
            icon: Icons.numbers,
            title: l10n.modifyCompletedQuantity,
            onTap: () => pick(_CompletedWishOption.modifyQuantity),
          ),
        AppListTile(
          icon: Icons.undo,
          title: l10n.unmarkWishAsCompleted,
          onTap: () => pick(_CompletedWishOption.uncomplete),
        ),
        const Gap(16),
      ],
    );
  }
}
