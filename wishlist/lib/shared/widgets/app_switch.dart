import 'package:flutter/material.dart';
import 'package:wishlist/shared/theme/colors.dart';

/// Interrupteur aux couleurs de l'app : un rond crème de taille fixe sur un
/// fond [AppColors.pastelGray], qui prend la couleur principale du thème
/// (celle de la wishlist) quand il est activé.
///
/// [activeIcon] et [inactiveIcon] s'affichent dans le rond : l'état se lit
/// sans dépendre de la couleur.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeIcon,
    this.inactiveIcon,
  });

  static const _duration = Duration(milliseconds: 200);
  static const double _trackWidth = 56;
  static const double _trackHeight = 32;
  static const double _thumbPadding = 3;
  static const double _thumbSize = _trackHeight - 2 * _thumbPadding;

  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? activeIcon;
  final IconData? inactiveIcon;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).primaryColor;
    final icon = value ? activeIcon : inactiveIcon;

    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        // Zone tactile de 44 px de haut autour du fond
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeInOut,
            width: _trackWidth,
            height: _trackHeight,
            padding: const EdgeInsets.all(_thumbPadding),
            decoration: BoxDecoration(
              color: value ? activeColor : AppColors.pastelGray,
              borderRadius: BorderRadius.circular(_trackHeight / 2),
            ),
            child: AnimatedAlign(
              duration: _duration,
              curve: Curves.easeInOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: icon == null
                    ? null
                    : Icon(
                        icon,
                        size: 16,
                        color: value ? activeColor : AppColors.makara,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
