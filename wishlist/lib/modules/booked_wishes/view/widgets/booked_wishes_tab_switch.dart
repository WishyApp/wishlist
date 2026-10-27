import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

enum BookedWishesTab {
  /// Bookings whose wish the owner has not fully received yet
  toGive,

  /// Bookings whose wish the owner received
  given,
}

/// Segmented control switching between the bookings left to give and the
/// given ones
class BookedWishesTabSwitch extends StatelessWidget {
  const BookedWishesTabSwitch({
    super.key,
    required this.current,
    required this.toGiveCount,
    required this.givenCount,
    required this.onChanged,
  });

  final BookedWishesTab current;
  final int toGiveCount;
  final int givenCount;
  final ValueChanged<BookedWishesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.pastelGray,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: l10n.bookedWishesTabToGive,
              count: toGiveCount,
              isSelected: current == BookedWishesTab.toGive,
              onTap: () => onChanged(BookedWishesTab.toGive),
            ),
          ),
          const Gap(4),
          Expanded(
            child: _Tab(
              label: l10n.bookedWishesTabGiven,
              count: givenCount,
              isSelected: current == BookedWishesTab.given,
              onTap: () => onChanged(BookedWishesTab.given),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(14));

    return Semantics(
      button: true,
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
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.smaller.copyWith(
                      color: AppColors.darkGrey,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(6),
                Text(
                  '$count',
                  style: AppTextStyles.smaller.copyWith(
                    color: AppColors.darkGrey,
                    fontWeight: FontWeight.w600,
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
