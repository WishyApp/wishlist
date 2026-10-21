import 'package:flutter/material.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/utils/not_found_error.dart';
import 'package:wishlist/shared/widgets/error_page_with_back.dart';

/// Full-page state of a wish screen whose data failed to load.
///
/// A wish that cannot be found (deleted, or no longer visible to the user,
/// for instance after its wishlist became private) is not worth retrying: it
/// only gets a message. Any other failure can be retried. The back button
/// stays available in both cases.
class WishLoadError extends StatelessWidget {
  const WishLoadError({
    super.key,
    required this.error,
    required this.onRetry,
    this.isRetrying = false,
  });

  final Object error;
  final Future<void> Function() onRetry;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    if (isNotFoundError(error)) {
      return ErrorPageWithBack.unavailable(
        message: context.l10n.wishUnavailable,
      );
    }

    return ErrorPageWithBack.failure(
      error: error,
      onRetry: onRetry,
      isRetrying: isRetrying,
    );
  }
}
