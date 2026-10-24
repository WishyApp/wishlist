import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// A birthday as a day and a month, without a year.
///
/// February 29 is valid: there is no year to check it against.
@immutable
class Birthday {
  // The assert has to be a constant expression (the constructor is const):
  // it spells the same rule as [daysInMonth]. Keep both, and the CHECK of
  // `profile_birthdays` in SQL, in line.
  const Birthday({required this.month, required this.day})
      : assert(month >= 1 && month <= 12, 'month must be between 1 and 12'),
        assert(
          day >= 1 &&
              day <=
                  (month == 2
                      ? 29
                      : (month == 4 || month == 6 || month == 9 || month == 11)
                          ? 30
                          : 31),
          'day does not exist in this month',
        );

  factory Birthday.fromJson(Map<String, dynamic> json) {
    return Birthday(
      month: json['month'] as int,
      day: json['day'] as int,
    );
  }

  final int month;
  final int day;

  /// Number of days of [month], February counting 29.
  ///
  /// Same rule as the constructor assert and the CHECK constraint of the
  /// `profile_birthdays` table.
  static int daysInMonth(int month) {
    return month == 2
        ? 29
        : (month == 4 || month == 6 || month == 9 || month == 11)
            ? 30
            : 31;
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'day': day,
    };
  }

  /// "12 mars" / "March 12", following [locale]. Needs the date symbols of
  /// [locale] loaded (the Flutter localization delegates do it in the app).
  String format(String locale) {
    return DateFormat.MMMMd(locale).format(DateTime(2024, month, day));
  }

  @override
  bool operator ==(Object other) =>
      other is Birthday && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(month, day);
}
