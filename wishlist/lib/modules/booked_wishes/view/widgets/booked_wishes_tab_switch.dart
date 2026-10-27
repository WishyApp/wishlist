import 'package:flutter/material.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/widgets/app_segmented_control.dart';

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

    return AppSegmentedControl<BookedWishesTab>(
      selected: current,
      onChanged: onChanged,
      segments: [
        AppSegment(
          value: BookedWishesTab.toGive,
          label: l10n.bookedWishesTabToGive,
          trailingText: '$toGiveCount',
        ),
        AppSegment(
          value: BookedWishesTab.given,
          label: l10n.bookedWishesTabGiven,
          trailingText: '$givenCount',
        ),
      ],
    );
  }
}
