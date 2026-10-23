import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// A birthday as a day and a month, without a year.
///
/// February 29 is valid: there is no year to check it against.
@immutable
class Birthday {
  const Birthday({required this.month, required this.day});

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

  /// "12 mars" / "March 12", following [locale].
  String format(String locale) {
    return DateFormat.MMMMd(locale).format(DateTime(2024, month, day));
  }

  @override
  bool operator ==(Object other) =>
      other is Birthday && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(month, day);
}
