import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/wishs/view/widgets/wish_load_error.dart';
import 'package:wishlist/modules/wishs/view/wish_form_screen.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/infra/utils/not_found_error.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/utils/retry_providers_extension.dart';

class EditWishScreen extends ConsumerWidget {
  const EditWishScreen({
    super.key,
    required this.wishId,
  });

  final int wishId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishAsync = ref.watch(watchWishByIdProvider(wishId));

    return wishAsync.when(
      // A failed refetch must not unmount the form and lose the user's edits,
      // unless the wish is gone
      skipError: wishAsync.hasValue && !isNotFoundError(wishAsync.error),
      data: (wish) => WishFormScreen(
        wishlistId: wish.wishlistId,
        wish: wish,
      ),
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => WishLoadError(
        error: error,
        onRetry: () => ref.retryFailed([watchWishByIdProvider(wishId)]),
        isRetrying: ref.isRetryingAny([watchWishByIdProvider(wishId)]),
      ),
    );
  }
}
