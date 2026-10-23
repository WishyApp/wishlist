import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/utils/formatters.dart';

class BookedWishesStats extends StatelessWidget {
  const BookedWishesStats({
    super.key,
    required this.bookedWishes,
    required this.countLabel,
  });

  final List<BookedWishWithDetails> bookedWishes;
  final String countLabel;

  double? get _totalBudget {
    double total = 0;
    var hasPrice = false;

    for (final bookedWish in bookedWishes) {
      final price = bookedWish.wish.price;
      if (price != null && price > 0) {
        total += price;
        hasPrice = true;
      }
    }

    return hasPrice ? total : null;
  }

  @override
  Widget build(BuildContext context) {
    final totalBudget = _totalBudget;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            Icons.card_giftcard,
            size: 24,
            color: Theme.of(context).primaryColor,
          ),
          const Gap(6),
          Expanded(
            // Text.rich, unlike RichText, follows the system text scale
            child: Text.rich(
              TextSpan(
                style: AppTextStyles.small.copyWith(
                  color: AppColors.darkGrey,
                ),
                children: [
                  TextSpan(
                    text: countLabel,
                    style: const TextStyle(
                      color: AppColors.darkGrey,
                    ),
                  ),
                  if (totalBudget != null) ...[
                    const TextSpan(text: ' • '),
                    TextSpan(
                      text: Formatters.currency(
                        totalBudget,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
