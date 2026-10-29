import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/page_layout_empty/page_layout_empty_content.dart';
import 'package:wishlist/shared/widgets/dialogs/create_dialog.dart';

/// Shown under the header when the user has no wishlist yet.
class HomeEmptyWishlists extends ConsumerWidget {
  const HomeEmptyWishlists({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: PageLayoutEmptyContent(
        illustrationUrl: Assets.svg.noWishlist,
        illustrationHeight: MediaQuery.sizeOf(context).height / 4,
        title: l10n.homeNoWishlist,
        callToAction: l10n.createButton,
        onCallToAction: () => showCreateDialog(context, ref),
      ),
    );
  }
}
