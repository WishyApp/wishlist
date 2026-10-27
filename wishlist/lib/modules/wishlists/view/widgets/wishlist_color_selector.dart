import 'package:flutter/material.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/theme/colors.dart';

/// Pastilles des couleurs de wishlist ([AppColors.colorPalette]), la couleur
/// [selected] cochée.
class WishlistColorSelector extends StatelessWidget {
  const WishlistColorSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in AppColors.colorPalette.entries)
          _ColorSwatch(
            color: entry.key,
            label: _colorLabel(context.l10n, entry.value),
            isSelected: entry.key.toARGB32() == selected.toARGB32(),
            onTap: () => onSelected(entry.key),
          ),
      ],
    );
  }

  static String _colorLabel(AppLocalizations l10n, String colorName) {
    return switch (colorName) {
      'blue' => l10n.colorBlue,
      'purple' => l10n.colorPurple,
      'yellow' => l10n.colorYellow,
      'green' => l10n.colorGreen,
      _ => colorName,
    };
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  static const double _tapTargetSize = 44;
  static const double _swatchSize = 32;

  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: _tapTargetSize / 2,
        child: SizedBox.square(
          dimension: _tapTargetSize,
          child: Center(
            child: Container(
              width: _swatchSize,
              height: _swatchSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: AppColors.darkGrey, width: 2)
                    : null,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 18,
                      color: AppColors.background,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
