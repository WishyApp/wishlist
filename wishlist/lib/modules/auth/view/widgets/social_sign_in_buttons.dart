import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// "Or" separator then the Apple and Google buttons, or nothing when neither
/// is available.
///
/// Apple only shows on iOS, where the App Store requires it next to Google.
/// Google only shows when [showGoogle] is true, i.e. its client IDs are set.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.showGoogle,
    required this.onGooglePressed,
    required this.onApplePressed,
    required this.isEnabled,
  });

  static const _height = 52.0;
  static final _borderRadius = BorderRadius.circular(16);

  final bool showGoogle;
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showApple = defaultTargetPlatform == TargetPlatform.iOS;

    if (!showApple && !showGoogle) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      ignoring: !isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(24),
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.pastelGray)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    l10n.socialSignInSeparator,
                    style: AppTextStyles.smaller.copyWith(
                      color: AppColors.makara,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.pastelGray)),
              ],
            ),
            const Gap(16),
            if (showApple)
              SignInWithAppleButton(
                text: l10n.continueWithApple,
                onPressed: onApplePressed,
                height: _height,
                borderRadius: _borderRadius,
              ),
            if (showApple && showGoogle) const Gap(12),
            if (showGoogle)
              SizedBox(
                height: _height,
                child: OutlinedButton(
                  onPressed: onGooglePressed,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: AppColors.pastelGray),
                    shape: RoundedRectangleBorder(
                      borderRadius: _borderRadius,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        Assets.svg.googleLogo,
                        width: 18,
                        height: 18,
                      ),
                      const Gap(12),
                      Text(
                        l10n.continueWithGoogle,
                        style: AppTextStyles.small.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
