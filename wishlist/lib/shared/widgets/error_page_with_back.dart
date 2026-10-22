import 'package:flutter/material.dart';
import 'package:wishlist/shared/page_layout_error/page_layout_error.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Full-page state of a screen that cannot show its content, with a back
/// button so that the user is never stuck on it.
///
/// Its body is either a message ([ErrorPageWithBack.unavailable], for content
/// that is gone and not worth retrying) or a [PageLayoutError]
/// ([ErrorPageWithBack.failure], for a load that failed and can be retried).
class ErrorPageWithBack extends StatelessWidget {
  const ErrorPageWithBack._({
    super.key,
    required this.body,
    this.onBack,
  });

  /// Page whose body only explains that the content is not available.
  ErrorPageWithBack.unavailable({
    Key? key,
    required String message,
    VoidCallback? onBack,
  }) : this._(key: key, body: _UnavailableMessage(message), onBack: onBack);

  /// Page whose body explains a load failure and offers to retry it.
  ErrorPageWithBack.failure({
    Key? key,
    required Object error,
    required Future<void> Function() onRetry,
    bool isRetrying = false,
    VoidCallback? onBack,
  }) : this._(
          key: key,
          body: PageLayoutError(
            error: error,
            onRetry: onRetry,
            isRetrying: isRetrying,
          ),
          onBack: onBack,
        );

  final Widget body;

  /// Makes the back button explicit and gives it this action. Without it, the
  /// app bar shows the back button of the route (and none when there is no
  /// route to go back to).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
      ),
      body: body,
    );
  }
}

class _UnavailableMessage extends StatelessWidget {
  const _UnavailableMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: AppTextStyles.medium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
