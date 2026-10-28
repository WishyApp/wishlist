import 'package:flutter/material.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/app_wave_pattern.dart';

/// AppBar de l'écran des paramètres d'une wishlist : « Paramètres » au-dessus
/// du nom de la wishlist, qui suit le champ en direct sans être éditable.
class WishlistSettingsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const WishlistSettingsAppBar({
    super.key,
    required this.wishlistName,
    required this.backgroundColor,
  });

  static const double _borderRadius = 32;

  final String wishlistName;
  final Color backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_borderRadius),
        ),
        child: AppWavePattern(
          backgroundColor: backgroundColor,
          preset: WavePreset.appBar,
          rotationType: WaveRotationType.fixed,
          rotationAngle: 45,
          child: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.background,
            elevation: 0,
            centerTitle: true,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.wishlistSettingsTitle,
                    style: AppTextStyles.tiny.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    wishlistName,
                    style: AppTextStyles.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
