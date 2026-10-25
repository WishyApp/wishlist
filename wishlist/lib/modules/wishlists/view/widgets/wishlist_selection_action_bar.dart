import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Barre d'actions fixée en bas de l'écran en mode sélection. Elle n'affiche
/// pas le nombre de wishs sélectionnés : la carte de sélection s'en charge
class WishlistSelectionActionBar extends StatelessWidget {
  const WishlistSelectionActionBar({
    super.key,
    required this.onComplete,
    required this.onMove,
    required this.onDelete,
  });

  static const double _padding = 8;

  final VoidCallback onComplete;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        _padding,
        _padding,
        _padding,
        _padding + bottomInset,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGrey.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ActionBarButton(
              icon: Icons.check_circle_outline,
              label: l10n.wishlistSelectionComplete,
              onPressed: onComplete,
            ),
          ),
          const Gap(_padding),
          Expanded(
            child: _ActionBarButton(
              icon: Icons.drive_file_move,
              label: l10n.wishlistSelectionMove,
              onPressed: onMove,
            ),
          ),
          const Gap(_padding),
          Expanded(
            child: _ActionBarButton(
              icon: Icons.delete,
              label: l10n.wishlistSelectionDelete,
              onPressed: onDelete,
              foregroundColor: AppColors.darken(Colors.red),
              backgroundColor: Colors.red.shade50,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBarButton extends StatelessWidget {
  const _ActionBarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foregroundColor = AppColors.darkGrey,
    this.backgroundColor = Colors.transparent,
  });

  static const double _minHeight = 56;

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);

    return Semantics(
      button: true,
      child: Material(
        color: backgroundColor,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foregroundColor),
                  const Gap(4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.smaller.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.bold,
                    ),
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
