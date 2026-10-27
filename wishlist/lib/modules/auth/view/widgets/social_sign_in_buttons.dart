import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
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
              _SocialButton(
                onPressed: onApplePressed,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                logo: const Icon(Icons.apple, size: 22),
                label: l10n.continueWithApple,
              ),
            if (showApple && showGoogle) const Gap(12),
            if (showGoogle)
              _SocialButton(
                onPressed: onGooglePressed,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                borderColor: AppColors.pastelGray,
                logo: SvgPicture.asset(
                  Assets.svg.googleLogo,
                  width: 18,
                  height: 18,
                ),
                label: l10n.continueWithGoogle,
              ),
          ],
        ),
      ),
    );
  }
}

/// Same shape and text style for both providers, only the colors and the
/// logo change: Apple's guidelines allow a custom button in black with the
/// white logo.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.logo,
    required this.label,
    this.borderColor,
  });

  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Widget logo;
  final String label;

  @override
  Widget build(BuildContext context) {
    final borderColor = this.borderColor;

    return SizedBox(
      height: SocialSignInButtons._height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: borderColor != null
              ? BorderSide(color: borderColor)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: SocialSignInButtons._borderRadius,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            logo,
            const Gap(12),
            Text(
              label,
              style: AppTextStyles.small.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
