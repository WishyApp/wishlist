import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/widgets/dialogs/app_dialog.dart';
import 'package:wishlist/shared/widgets/past_date_picker.dart';

/// Asks for the day one or more wishes were received, up to today.
///
/// [onConfirm] runs with the picked day while the confirm button loads: the
/// dialog closes once it succeeds, and stays open on an error. Returns the
/// picked day (local midnight), or null when the dialog was dismissed.
Future<DateTime?> showCompletionDateDialog(
  BuildContext context, {
  required String title,
  required String explanation,
  required String confirmButtonLabel,
  String? wishName,
  DateTime? initialValue,
  Future<void> Function(DateTime completedAt)? onConfirm,
}) async {
  final now = DateTime.now();
  final initial = initialValue ?? now;
  var selected = DateTime(initial.year, initial.month, initial.day);
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
    onConfirm: () async {
      await onConfirm?.call(selected);
      confirmed = selected;
    },
  );

  return confirmed;
}
