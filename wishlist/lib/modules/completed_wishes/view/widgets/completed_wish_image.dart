import 'package:flutter/material.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/pill.dart';
import 'package:wishlist/shared/widgets/wish_image.dart';

/// Image of a completed wish, with the received quantity when above 1
class CompletedWishImage extends StatelessWidget {
  const CompletedWishImage({
    super.key,
    required this.iconUrl,
    required this.quantity,
    required this.size,
    required this.borderRadius,
    this.showCompletedBadge = false,
  });

  final String? iconUrl;
  final int quantity;
  final double size;
  final double borderRadius;

  /// Marks the wish as completed, for lists that mix them with other wishes
  /// or show them without a title saying so
  final bool showCompletedBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        WishImage(
          iconUrl: iconUrl,
          size: size,
          borderRadius: borderRadius,
        ),
        if (showCompletedBadge)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
          ),
        if (quantity > 1)
          Positioned(
            bottom: -4,
            right: -4,
            child: Pill(
              text: 'x$quantity',
              backgroundColor: Theme.of(context).primaryColor,
              textStyle: AppTextStyles.smaller,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
            ),
          ),
      ],
    );
  }
}
