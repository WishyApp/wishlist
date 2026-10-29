import 'package:flutter/material.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/widgets/settings_line.dart';

/// Rounded group of [SettingsLine]s, with an optional title above.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    required this.children,
  });

  final String? title;
  final List<SettingsLine> children;

  @override
  Widget build(BuildContext context) {
    final title = this.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (title != null)
          Text(
            title,
            style: AppTextStyles.smaller,
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            spacing: 2,
            children: children,
          ),
        ),
      ],
    );
  }
}
