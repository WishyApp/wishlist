import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_selection_action_bar.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/shared/widgets/inert_switcher_layout.dart';
import 'package:wishlist/shared/widgets/nav_bar_add_button.dart';

/// Actions du propriétaire posées sur la liste : le bouton d'ajout, remplacé
/// en mode sélection par la barre d'actions du bas
class WishlistFloatingActions extends ConsumerWidget {
  const WishlistFloatingActions({
    super.key,
    required this.wishlistId,
    required this.onAdd,
    required this.onDelete,
    required this.onMove,
    required this.onComplete,
  });

  static const Duration _animationDuration = Duration(milliseconds: 250);

  final int wishlistId;
  final VoidCallback onAdd;
  final VoidCallback onDelete;
  final VoidCallback onMove;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelection = ref.watch(
      wishlistScreenNotifierProvider(wishlistId)
          .select((state) => state.isSelectionMode),
    );

    // Les zones vides laissent passer les touches vers la liste
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
            right: 24,
            child: AnimatedSwitcher(
              duration: _animationDuration,
              layoutBuilder: inertSwitcherLayout(),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              // Aux couleurs de la wishlist, par le thème de l'écran
              child: isSelection
                  ? null
                  : NavBarAddButton(icon: Icons.add, onPressed: onAdd),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSwitcher(
              duration: _animationDuration,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: inertSwitcherLayout(
                alignment: Alignment.bottomCenter,
              ),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
              child: isSelection
                  ? WishlistSelectionActionBar(
                      onComplete: onComplete,
                      onMove: onMove,
                      onDelete: onDelete,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
