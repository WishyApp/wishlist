import 'package:flutter/material.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/utils/network_error.dart';
import 'package:wishlist/shared/page_layout_empty/page_layout_empty_content.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Shown in place of the wishlists grid when they fail to load: the header and
/// the received wishes row stay above it.
class HomeWishlistsError extends StatelessWidget {
  const HomeWishlistsError({
    super.key,
    required this.error,
    required this.onRetry,
    required this.isRetrying,
  });

  final Object error;

  /// Reloads the wishlists, and completes once they are reloaded.
  final Future<void> Function() onRetry;

  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isNetwork = isNetworkError(error);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: PageLayoutEmptyContent(
        illustrationUrl:
            isNetwork ? Assets.svg.noConnection : Assets.svg.serverError,
        illustrationHeight: MediaQuery.sizeOf(context).height / 5,
        title: isNetwork ? l10n.networkErrorTitle : l10n.loadingErrorTitle,
        titleTextStyle: AppTextStyles.titleSmall,
        description: isNetwork
            ? l10n.networkErrorDescription
            : l10n.loadingErrorDescription,
        callToAction: l10n.retryButton,
        onCallToAction: _retrySilently,
        isCallToActionLoading: isRetrying,
      ),
    );
  }

  /// A new failure is already shown by this block: it must not escape as an
  /// uncaught error.
  Future<void> _retrySilently() async {
    try {
      await onRetry();
    } catch (_) {}
  }
}
