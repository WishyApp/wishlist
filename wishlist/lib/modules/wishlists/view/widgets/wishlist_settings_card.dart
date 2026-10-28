import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Carte d'un réglage de wishlist : une icône, un titre, une explication
/// facultative, un contrôle à droite ([trailing]) et/ou en dessous ([child]).
class WishlistSettingsCard extends StatelessWidget {
  const WishlistSettingsCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.trailing,
    this.child,
    this.onTap,
  });

  static const _borderRadius = BorderRadius.all(Radius.circular(16));

  final IconData icon;
  final String title;
  final String? description;
  final Widget? trailing;
  final Widget? child;

  /// Rend toute la carte cliquable (ex. un interrupteur qu'on bascule en
  /// touchant son libellé).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    final trailing = this.trailing;
    final child = this.child;

    return Material(
      color: AppColors.gainsboro,
      borderRadius: _borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: _borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.makara, size: 24),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.darkGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (description != null) ...[
                          const Gap(2),
                          Text(
                            description,
                            style: AppTextStyles.smaller.copyWith(
                              color: AppColors.makara,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const Gap(8),
                    trailing,
                  ],
                ],
              ),
              if (child != null) ...[
                const Gap(12),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
