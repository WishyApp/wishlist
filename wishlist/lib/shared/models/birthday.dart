import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// A birthday as a day and a month, without a year.
///
/// February 29 is valid: there is no year to check it against.
@immutable
class Birthday {
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
  static int daysInMonth(int month) {
    // Day 0 of the next month, in a leap year.
    return DateTime(2024, month + 1, 0).day;
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
