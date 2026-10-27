import 'package:flutter/material.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/widgets/app_segmented_control.dart';

/// Choix Publique / Privée d'une wishlist.
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

    return AppSegmentedControl<WishlistVisibility>(
      selected: selected,
      onChanged: onSelected,
      segments: [
        AppSegment(
          value: WishlistVisibility.public,
          label: l10n.public,
          icon: Icons.public,
        ),
        AppSegment(
          value: WishlistVisibility.private,
          label: l10n.private,
          icon: Icons.lock_outline,
        ),
      ],
    );
  }
}
