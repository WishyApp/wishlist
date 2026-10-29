import 'package:flutter/material.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

class SettingsLine extends StatelessWidget {
  const SettingsLine({
    super.key,
    required this.title,
    this.onTap,
    this.value,
  });

  final String title;

  /// Current value of the setting, shown before the arrow.
  final String? value;

  /// Null for an information line: no ripple, no arrow.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final onTap = this.onTap;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.smaller,
          ),
          if (value != null) ...[
            const SizedBox(width: 16),
            // A long value ellipsizes (large text scale) instead of
            // overflowing
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.smaller.copyWith(color: Colors.grey),
              ),
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ],
      ),
    );

    return Material(
      color: AppColors.gainsboro,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
