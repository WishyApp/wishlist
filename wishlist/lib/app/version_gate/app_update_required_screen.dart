import 'package:flutter/material.dart';
import 'package:wishlist/app/version_gate/update_text_variant.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/page_layout_empty/page_layout_empty.dart';
import 'package:wishlist/shared/theme/colors.dart';

/// Full-screen wall shown when the app version is older than the server's
/// minimum. No app bar and no back button: there is nowhere to go.
class AppUpdateRequiredScreen extends StatelessWidget {
  const AppUpdateRequiredScreen({super.key, this.onUpdate, this.platform});

  /// Opens the store. Null when the server gives no store page: the screen
  /// then only explains where to update from.
  final VoidCallback? onUpdate;

  /// `ios` or `android`: names the store in the text shown without a store
  /// page.
  final String? platform;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onUpdate = this.onUpdate;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: PageLayoutEmpty(
          illustrationUrl: Assets.svg.noWishBag,
          illustrationHeight: MediaQuery.sizeOf(context).height / 3.5,
          title: l10n.updateRequiredTitle,
          description: switch (UpdateTextVariant.of(
            hasLink: onUpdate != null,
            platform: platform,
          )) {
            UpdateTextVariant.iosStore =>
              l10n.updateRequiredNoLinkIosDescription,
            UpdateTextVariant.androidStore =>
              l10n.updateRequiredNoLinkAndroidDescription,
            UpdateTextVariant.generic => l10n.updateRequiredDescription,
          },
          callToAction: l10n.updateButton,
          onCallToAction: onUpdate,
        ),
      ),
    );
  }
}
