import 'package:flutter/cupertino.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Three wheels, day, month and year (in the order of the locale), to pick a
/// day up to today. The year wheel stops at the current year; the days and
/// months after today are greyed out, and the wheels go back to today if one
/// is picked.
///
/// The wheels look like those of the BirthdayPicker. [initialValue] is only
/// read when the picker is created, and brought back within the wheels (see
/// [clampDay]); its time is ignored, and so is the time of the days given to
/// [onChanged] (local midnight).
class PastDatePicker extends StatelessWidget {
  const PastDatePicker({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.now,
  });

  /// The first year of the wheel.
  static const minimumYear = 2000;

  final DateTime initialValue;
  final ValueChanged<DateTime> onChanged;

  /// Today, for tests: DateTime.now() when null.
  final DateTime? now;

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// The day of [date] if the wheels can show it, else the nearest one: from
  /// January 1 of [minimumYear] to the day of [now]. A day outside would trip
  /// the picker's assertions, or be shown as another day than the one kept.
  static DateTime clampDay(DateTime date, {required DateTime now}) {
    final day = _day(date);
    final today = _day(now);
    final first = DateTime(minimumYear);
    if (day.isAfter(today)) {
      return today;
    }
    return day.isBefore(first) ? first : day;
  }

  @override
  Widget build(BuildContext context) {
    final today = _day(now ?? DateTime.now());

    // The wheels take their text style from the Cupertino theme, which
    // defaults to the platform font: use the app's instead.
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        textTheme: CupertinoTextThemeData(
          dateTimePickerTextStyle: AppTextStyles.large.copyWith(
            color: AppColors.darkGrey,
          ),
        ),
      ),
      child: SizedBox(
        height: 180,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: clampDay(initialValue, now: today),
          minimumYear: minimumYear,
          maximumYear: today.year,
          maximumDate: today,
          onDateTimeChanged: (date) => onChanged(_day(date)),
        ),
      ),
    );
  }
}
