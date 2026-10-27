import 'package:flutter/material.dart';
import 'package:wishlist/shared/theme/colors.dart';

/// Interrupteur aux couleurs de l'app : un rond crème de taille fixe sur un
/// fond [AppColors.pastelGray], qui prend la couleur principale du thème
/// (celle de la wishlist) quand il est activé.
///
/// [activeIcon] et [inactiveIcon] s'affichent dans le rond : l'état se lit
/// sans dépendre de la couleur. Le rond roule d'un côté à l'autre, ses icônes
/// tournant et se fondant l'une dans l'autre, comme l'ancien interrupteur
/// (animation « rolling » d'animated_toggle_switch).
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeIcon,
    this.inactiveIcon,
  });

  static const _duration = Duration(milliseconds: 500);
  static const _curve = Curves.easeInOutCirc;
  static const double _trackWidth = 56;
  static const double _trackHeight = 32;
  static const double _thumbPadding = 3;
  static const double _thumbSize = _trackHeight - 2 * _thumbPadding;
  static const double _iconSize = 16;

  /// Angle dont tourne le rond en allant d'un bout à l'autre, s'il roulait
  /// sans glisser : distance parcourue / rayon.
  static const double _rollAngle =
      (_trackWidth - 2 * _thumbPadding - _thumbSize) / (_thumbSize / 2);

  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? activeIcon;
  final IconData? inactiveIcon;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).primaryColor;
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;

    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        // Zone tactile de 44 px de haut autour du fond
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          // 0 : désactivé, 1 : activé
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value ? 1 : 0),
            duration: _duration,
            curve: _curve,
            builder: (context, progress, _) {
              final angle = progress * _rollAngle * direction;

              return Container(
                width: _trackWidth,
                height: _trackHeight,
                padding: const EdgeInsets.all(_thumbPadding),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    AppColors.pastelGray,
                    activeColor,
                    progress,
                  ),
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                ),
                child: Align(
                  alignment: AlignmentDirectional(progress * 2 - 1, 0),
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _RollingIcon(
                          icon: inactiveIcon,
                          color: AppColors.makara,
                          angle: angle,
                          opacity: 1 - progress,
                        ),
                        // Arrive en tournant depuis l'autre côté
                        _RollingIcon(
                          icon: activeIcon,
                          color: activeColor,
                          angle: angle - _rollAngle * direction,
                          opacity: progress,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RollingIcon extends StatelessWidget {
  const _RollingIcon({
    required this.icon,
    required this.color,
    required this.angle,
    required this.opacity,
  });

  final IconData? icon;
  final Color color;
  final double angle;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon == null || opacity <= 0) {
      return const SizedBox.shrink();
    }

    return Transform.rotate(
      angle: angle,
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Icon(icon, size: AppSwitch._iconSize, color: color),
      ),
    );
  }
}
