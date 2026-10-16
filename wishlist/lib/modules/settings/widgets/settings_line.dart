import 'package:flutter/material.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

class SettingsLine extends StatelessWidget {
  const SettingsLine({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.toggled,
  });

  final String title;
  final VoidCallback onTap;
  final String? subtitle;

  /// Replaces the default chevron.
  final Widget? trailing;

  /// For a toggle row: the whole row (title and `trailing` switch) is exposed
  /// as a single toggleable semantics node labelled by the title.
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final line = Material(
      color: AppColors.gainsboro,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.smaller,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTextStyles.smaller.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );

    if (toggled == null) {
      return line;
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: title,
      hint: subtitle,
      toggled: toggled,
      onTap: onTap,
      child: line,
    );
  }
}
