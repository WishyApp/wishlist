import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Header shared by the empty states and the signup steps: an illustration, a
/// centered title and an optional centered description in makara.
class IllustratedHeader extends StatelessWidget {
  const IllustratedHeader({
    super.key,
    required this.illustration,
    required this.title,
    this.titleStyle = AppTextStyles.title,
    this.description,
    this.descriptionStyle = AppTextStyles.small,
    this.illustrationGap = 32,
    this.titleGap = 8,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  /// The drawing, sized by the caller.
  final Widget illustration;

  final String title;
  final TextStyle titleStyle;

  final String? description;

  /// Base style of the description, the makara color is applied on top.
  final TextStyle descriptionStyle;

  /// Space between the illustration and the title.
  final double illustrationGap;

  /// Space between the title and the description.
  final double titleGap;

  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final description = this.description;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        illustration,
        Gap(illustrationGap),
        Text(
          title,
          textAlign: TextAlign.center,
          style: titleStyle,
        ),
        if (description != null) ...[
          Gap(titleGap),
          Text(
            description,
            textAlign: TextAlign.center,
            style: descriptionStyle.copyWith(color: AppColors.makara),
          ),
        ],
      ],
    );
  }
}
