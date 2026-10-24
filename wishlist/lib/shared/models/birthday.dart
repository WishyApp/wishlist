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

  /// A birthday is "upcoming" when it is at most this many days away: today
  /// included, so 0 to 30, which is 31 dates. Further ones are shown without a
  /// countdown.
  static const upcomingDays = 30;

  /// Parses a `{month, day}` row, null if it is malformed (wrong types, month
  /// or day out of range). Unlike [Birthday.fromJson] it never asserts, so
  /// release builds treat invalid data the same way.
  static Birthday? tryFromJson(Map<String, dynamic> json) {
    final month = json['month'];
    final day = json['day'];
    if (month is! int || day is! int) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > daysInMonth(month)) {
      return null;
    }
    return Birthday(month: month, day: day);
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

  /// Number of days from [today] (local calendar date, time ignored) to the
  /// next occurrence of this birthday: 0 if it is today.
  ///
  /// Counted on calendar dates, not on durations: a day of 23 or 25 hours
  /// (daylight saving time change) must not shift the result. A February 29
  /// birthday is celebrated on February 28 in a common year.
  int daysUntil(DateTime today) {
    // The calendar date of the user, whatever the zone [today] comes in.
    final localToday = today.toLocal();
    final todayDate = DateTime.utc(
      localToday.year,
      localToday.month,
      localToday.day,
    );

    var next = _occurrenceIn(localToday.year);
    if (next.isBefore(todayDate)) {
      next = _occurrenceIn(localToday.year + 1);
    }

    return next.difference(todayDate).inDays;
  }

  /// [daysUntil] if the birthday is within [upcomingDays], null if it is
  /// further away: the one place of the "show a countdown" rule.
  int? upcomingIn(DateTime today) {
    final days = daysUntil(today);
    return days <= upcomingDays ? days : null;
  }

  DateTime _occurrenceIn(int year) {
    final isLeapYear = DateTime.utc(year, 3, 0).day == 29;
    final celebratedDay = month == 2 && day == 29 && !isLeapYear ? 28 : day;
    return DateTime.utc(year, month, celebratedDay);
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
