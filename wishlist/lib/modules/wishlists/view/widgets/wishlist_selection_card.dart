import 'package:flutter/material.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Carte affichée à la place des cartes de stats en mode sélection : seul
/// endroit de l'écran où apparaît le nombre de wishs sélectionnés
class WishlistSelectionCard extends StatelessWidget {
  const WishlistSelectionCard({
    super.key,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onExit,
  });

  /// Taille minimale des zones tactiles
  static const double _minTapSize = 48;

  /// Part maximale de la carte laissée au bouton "Tout sélectionner"
  static const double _maxButtonWidthRatio = 0.55;

  final int selectedCount;

  /// Null quand il n'y a rien à ajouter : aucun wish affiché (recherche sans
  /// résultat) ou tous déjà sélectionnés. Pour tout désélectionner, la croix
  /// quitte le mode sélection.
  final VoidCallback? onSelectAll;
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
      // Le bouton garde une vraie largeur avec un grand texte : c'est le
      // compteur qui rétrécit
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                // Annonce le nouveau compteur aux lecteurs d'écran à chaque
                // changement
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: l10n.wishlistSelectionCount(selectedCount),
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * _maxButtonWidthRatio,
                  ),
                  child: TextButton(
                    onPressed: onSelectAll,
                    style: TextButton.styleFrom(
                      foregroundColor: textColor,
                      disabledForegroundColor: textColor.withValues(alpha: 0.5),
                      minimumSize: const Size(_minTapSize, _minTapSize),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      l10n.wishlistSelectAll,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.smaller.copyWith(
                        fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }
}
