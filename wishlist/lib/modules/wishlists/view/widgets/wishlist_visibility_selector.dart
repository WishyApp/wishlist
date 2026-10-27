import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Choix Publique / Privée d'une wishlist, en deux segments.
class WishlistVisibilitySelector extends StatelessWidget {
  const WishlistVisibilitySelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final WishlistVisibility selected;
  final ValueChanged<WishlistVisibility> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pastelGray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _Segment(
                label: l10n.public,
                icon: Icons.public,
                isSelected: selected == WishlistVisibility.public,
                onTap: () => onSelected(WishlistVisibility.public),
              ),
            ),
            const Gap(4),
            Expanded(
              child: _Segment(
                label: l10n.private,
                icon: Icons.lock_outline,
                isSelected: selected == WishlistVisibility.private,
                onTap: () => onSelected(WishlistVisibility.private),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  static const _borderRadius = BorderRadius.all(Radius.circular(10));

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected ? AppColors.darkGrey : AppColors.makara;

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? AppColors.background : Colors.transparent,
        borderRadius: _borderRadius,
        elevation: isSelected ? 1 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: _borderRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foregroundColor),
                const Gap(8),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.smaller.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
