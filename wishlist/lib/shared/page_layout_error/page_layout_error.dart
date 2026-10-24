import 'package:flutter/material.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/utils/network_error.dart';
import 'package:wishlist/shared/page_layout_empty/page_layout_empty.dart';

/// Full-page state shown when a screen fails to load its data.
///
/// Explains whether the network or the server is at fault, and lets the user
/// retry with a button or a pull to refresh.
class PageLayoutError extends StatelessWidget {
  const PageLayoutError({
    super.key,
    required this.error,
    required this.onRetry,
    this.isRetrying = false,
    this.appBarTitle,
  });

  final Object error;

  /// Reloads the screen data, and completes once it is reloaded.
  final Future<void> Function() onRetry;

  /// Shows the retry button as loading, while the screen reloads its data.
  final bool isRetrying;
  final String? appBarTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isNetwork = isNetworkError(error);

    return PageLayoutEmpty(
      // Illustrations of their own: the flashlight shown before is also one
      // of the empty wishlist ones
      illustrationUrl:
          isNetwork ? Assets.svg.noConnection : Assets.svg.serverError,
      // Smaller than an empty state's: the description and the retry button
      // must stay above the floating nav bar on small screens
      illustrationHeight: MediaQuery.sizeOf(context).height / 3.5,
      title: isNetwork ? l10n.networkErrorTitle : l10n.loadingErrorTitle,
      description: isNetwork
          ? l10n.networkErrorDescription
          : l10n.loadingErrorDescription,
      callToAction: l10n.retryButton,
      onCallToAction: _retrySilently,
      isCallToActionLoading: isRetrying,
      onRefresh: _retrySilently,
      appBarTitle: appBarTitle,
    );
  }

  /// The pull to refresh waits for the reload, but a new failure is already
  /// shown by this page: it must not escape as an uncaught error.
  Future<void> _retrySilently() async {
    try {
      await onRetry();
    } catch (_) {}
  }
}
