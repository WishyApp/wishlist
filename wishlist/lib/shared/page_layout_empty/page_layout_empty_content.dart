import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/widgets/illustrated_header.dart';

class PageLayoutEmptyContent extends StatelessWidget {
  const PageLayoutEmptyContent({
    super.key,
    required this.illustrationUrl,
    required this.illustrationHeight,
    required this.title,
    this.titleTextStyle = AppTextStyles.title,
    this.description,
    required this.callToAction,
    required this.onCallToAction,
    this.isCallToActionLoading = false,
  });

  final String illustrationUrl;
  final double illustrationHeight;
  final String title;
  final TextStyle titleTextStyle;
  final String? description;
  final String? callToAction;
  final Function()? onCallToAction;
  final bool isCallToActionLoading;

  @override
  Widget build(BuildContext context) {
    final callToAction = this.callToAction;
    final onCallToAction = this.onCallToAction;
    final hasCallToAction = callToAction != null && onCallToAction != null;

    return Column(
      children: <Widget>[
        IllustratedHeader(
          illustration: SvgPicture.asset(
            illustrationUrl,
            height: illustrationHeight,
          ),
          title: title,
          titleStyle: titleTextStyle,
          description: description,
        ),
        const Gap(16),
        if (hasCallToAction)
          PrimaryButton(
            text: callToAction,
            onPressed: onCallToAction,
            style: BaseButtonStyle.large,
            isLoading: isCallToActionLoading,
          ),
      ],
    );
  }
}
