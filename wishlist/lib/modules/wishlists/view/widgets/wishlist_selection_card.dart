import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Carte affichée à la place des cartes de stats en mode sélection : seul
/// endroit de l'écran où apparaît le nombre de wishs sélectionnés
class WishlistSelectionCard extends StatelessWidget {
  const WishlistSelectionCard({
    super.key,
    required this.selectedCount,
    required this.areAllSelected,
    required this.onToggleSelectAll,
    required this.onExit,
  });

  /// Taille minimale des zones tactiles
  static const double _minTapSize = 48;

  final int selectedCount;

  /// Tous les wishs affichés sont sélectionnés : le bouton les désélectionne
  final bool areAllSelected;

  /// Null quand aucun wish n'est affiché (recherche sans résultat)
  final VoidCallback? onToggleSelectAll;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const textColor = AppColors.background;
    // La couleur foncée de la wishlist, foncée encore si le texte n'y est pas
    // assez lisible (jaune, vert, bleu)
    final backgroundColor = AppColors.darkenForContrast(
      Theme.of(context).primaryColorDark,
      foreground: textColor,
    );

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Annonce le nouveau compteur aux lecteurs d'écran à chaque
          // changement
          Semantics(
            container: true,
            liveRegion: true,
            label: l10n.wishlistSelectionCount(selectedCount),
            excludeSemantics: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCount.toString(),
                  style: AppTextStyles.title.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                Text(
                  l10n.wishlistSelectionCountLabel(selectedCount),
                  style: AppTextStyles.smaller.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onToggleSelectAll,
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  disabledForegroundColor: textColor.withValues(alpha: 0.5),
                  minimumSize: const Size(_minTapSize, _minTapSize),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  areAllSelected
                      ? l10n.wishlistDeselectAll
                      : l10n.wishlistSelectAll,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.smaller.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onExit,
            tooltip: l10n.wishlistExitSelection,
            color: textColor,
            constraints: const BoxConstraints(
              minWidth: _minTapSize,
              minHeight: _minTapSize,
            ),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
