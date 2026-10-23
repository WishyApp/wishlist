import 'package:flutter/material.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

class SettingsLine extends StatelessWidget {
  const SettingsLine({
    super.key,
    required this.title,
    required this.onTap,
    this.value,
  });

  final String title;

  /// Current value of the setting, shown before the arrow.
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gainsboro,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.smaller,
              ),
              const Spacer(),
              if (value != null) ...[
                Text(
                  value!,
                  style: AppTextStyles.smaller.copyWith(color: Colors.grey),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
