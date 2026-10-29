import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/widgets/dialogs/app_dialog.dart';
import 'package:wishlist/shared/widgets/past_date_picker.dart';

/// Asks for the day one or more wishes were received, up to today, starting on
/// [initialValue] (today when null).
///
/// Returns the picked day (local midnight), or null when the dialog was
/// dismissed. The dialog saves nothing: it can be dismissed at any time, the
/// caller saves the day once it is closed.
Future<DateTime?> showCompletionDateDialog(
  BuildContext context, {
  required String title,
  required String explanation,
  required String confirmButtonLabel,
  String? wishName,
  DateTime? initialValue,
}) async {
  // clock, not DateTime: tests fix the day
  final now = clock.now();
  var selected = PastDatePicker.clampDay(initialValue ?? now, now: now);
  DateTime? confirmed;

  await showAppDialog(
    context,
    title: title,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          explanation,
          style: AppTextStyles.small.copyWith(color: AppColors.makara),
          textAlign: TextAlign.center,
        ),
        if (wishName != null) ...[
          const Gap(8),
          Text(
            wishName,
            style: AppTextStyles.small.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const Gap(16),
        // The dialog sizes its content to its intrinsic width, which the
        // wheels cannot give: they take the width of the dialog instead
        SizedBox(
          width: double.maxFinite,
          child: PastDatePicker(
            initialValue: selected,
            now: now,
            onChanged: (day) => selected = day,
          ),
        ),
      ],
    ),
    confirmButtonLabel: confirmButtonLabel,
    onCancel: () {},
    onConfirm: () async => confirmed = selected,
  );

  return confirmed;
}
