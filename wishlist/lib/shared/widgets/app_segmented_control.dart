import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// One choice of an [AppSegmentedControl].
class AppSegment<T> {
  const AppSegment({
    required this.value,
    required this.label,
    this.icon,
    this.trailingText,
  });

  final T value;
  final String label;

  /// Shown before the label
  final IconData? icon;

  /// Shown after the label, less bold (ex. a count)
  final String? trailingText;
}

/// Choice between a few [segments] of equal width: the selected one is a
/// raised pill on a [AppColors.pastelGray] background.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.pastelGray,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Row(
        spacing: 4,
        children: [
          for (final segment in segments)
            Expanded(
              child: _Segment(
                segment: segment,
                isSelected: segment.value == selected,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final AppSegment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(14));
    final icon = segment.icon;
    final trailingText = segment.trailingText;

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            // Grows with the text scale
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.background : Colors.transparent,
              borderRadius: borderRadius,
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.darkGrey),
                  const Gap(6),
                ],
                Flexible(
                  child: Text(
                    segment.label,
                    style: AppTextStyles.smaller.copyWith(
                      color: AppColors.darkGrey,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailingText != null) ...[
                  const Gap(6),
                  Text(
                    trailingText,
                    style: AppTextStyles.smaller.copyWith(
                      color: AppColors.darkGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
