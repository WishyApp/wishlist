import 'package:flutter/cupertino.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// The look of the app's wheels (BirthdayPicker, PastDatePicker): their
/// height, and the app's text style instead of the platform font, which the
/// wheels take from the Cupertino theme by default.
class WheelPickerStyle extends StatelessWidget {
  const WheelPickerStyle({super.key, required this.child});

  static const double height = 180;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyles.large.copyWith(color: AppColors.darkGrey);

    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        textTheme: CupertinoTextThemeData(
          pickerTextStyle: textStyle,
          dateTimePickerTextStyle: textStyle,
        ),
      ),
      child: SizedBox(height: height, child: child),
    );
  }
}
