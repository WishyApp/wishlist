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

  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.pastelGray,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Stack(
        children: [
          // The white pill slides under the selected tab
          Positioned.fill(
            child: _SlidingPill(
              isAtStart: current == BookedWishesTab.toGive,
              gap: _gap,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Tab(
                  label: l10n.bookedWishesTabToGive,
                  count: toGiveCount,
                  isSelected: current == BookedWishesTab.toGive,
                  onTap: () => onChanged(BookedWishesTab.toGive),
                ),
              ),
              const Gap(_gap),
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
        ],
      ),
    );
  }
}

const _tabBorderRadius = BorderRadius.all(Radius.circular(14));

/// Background of the selected tab, sliding from one tab to the other
class _SlidingPill extends StatelessWidget {
  const _SlidingPill({required this.isAtStart, required this.gap});

  final bool isAtStart;

  /// Space between the two tabs
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedAlign(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        alignment: isAtStart
            ? AlignmentDirectional.centerStart
            : AlignmentDirectional.centerEnd,
        child: SizedBox(
          width: (constraints.maxWidth - gap) / 2,
          height: constraints.maxHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: _tabBorderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
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
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: _tabBorderRadius,
          child: Container(
            // Grows with the text scale
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
