import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';

/// Tells that [count] wishes were completed, with a button that opens the
/// completed wishes screen.
///
/// The router is read now: the snackbar outlives the screen that shows it,
/// which can be leaving (the wish screen pops once its wish is completed).
void showWishesCompletedSnackBar(BuildContext context, int count) {
  final l10n = context.l10n;
  final router = GoRouter.of(context);

  showAppSnackBar(
    context,
    l10n.wishesCompletedSnackBar(count),
    type: SnackBarType.success,
    duration: const Duration(seconds: 6),
    actionLabel: l10n.snackBarSeeAction,
    onAction: () => router.push(CompletedWishesRoute().location),
  );
}
