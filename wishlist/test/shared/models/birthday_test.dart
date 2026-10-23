import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/models/birthday.dart';

import '../../pump_app.dart';

void main() {
  test('fromJson reads month and day', () {
    final birthday = Birthday.fromJson(const {'month': 3, 'day': 12});

    expect(birthday.month, 3);
    expect(birthday.day, 12);
  });

  test('toJson only holds month and day', () {
    expect(
      const Birthday(month: 2, day: 29).toJson(),
      {'month': 2, 'day': 29},
    );
  });

  test('fromJson ignores the other columns of the row', () {
    final birthday = Birthday.fromJson(const {
      'profile_id': 'abc',
      'month': 12,
      'day': 31,
      'created_at': '2026-10-23T00:00:00Z',
    });

    expect(birthday, const Birthday(month: 12, day: 31));
  });

  test('refuses dates that exist in no year', () {
    expect(() => Birthday(month: 4, day: 31), throwsAssertionError);
    expect(() => Birthday(month: 2, day: 30), throwsAssertionError);
    expect(() => Birthday(month: 13, day: 1), throwsAssertionError);
    expect(() => Birthday(month: 1, day: 0), throwsAssertionError);
    expect(const Birthday(month: 2, day: 29).day, 29);
  });

  test('daysInMonth counts 29 for February', () {
    expect(Birthday.daysInMonth(2), 29);
    expect(Birthday.daysInMonth(4), 30);
    expect(Birthday.daysInMonth(1), 31);
    expect(Birthday.daysInMonth(12), 31);
  });

  // Month names come from the date symbols that the localization delegates of
  // the app load, hence a widget test.
  testWidgets('format follows the locale, February 29 included',
      (tester) async {
    await tester.pumpApp(const SizedBox.shrink());

    expect(const Birthday(month: 3, day: 12).format('fr'), '12 mars');
    expect(const Birthday(month: 3, day: 12).format('en'), 'March 12');
    expect(const Birthday(month: 2, day: 29).format('fr'), '29 février');
  });

  group('daysUntil', () {
    int days(Birthday b, DateTime today) => b.daysUntil(today);
    int daysOn(int month, int day, DateTime today) =>
        days(Birthday(month: month, day: day), today);

    test('is 0 today, whatever the time of the day', () {
      const b = Birthday(month: 3, day: 12);

      expect(days(b, DateTime(2026, 3, 12)), 0);
      expect(days(b, DateTime(2026, 3, 12, 23, 59, 59)), 0);
    });

    test('is 1 tomorrow, even a minute before midnight', () {
      const b = Birthday(month: 3, day: 12);

      expect(days(b, DateTime(2026, 3, 11)), 1);
      expect(days(b, DateTime(2026, 3, 11, 23, 59)), 1);
    });

    test('counts forward in the same year', () {
      expect(daysOn(3, 12, DateTime(2026, 3, 7)), 5);
      expect(daysOn(12, 25, DateTime(2026)), 358);
    });

    test('goes to next year once the birthday is past', () {
      expect(daysOn(3, 12, DateTime(2026, 3, 13)), 364);
      // Crosses February 29, 2028
      expect(daysOn(3, 12, DateTime(2027, 3, 13)), 365);
    });

    test('rolls over the new year', () {
      expect(daysOn(1, 1, DateTime(2026, 12, 31)), 1);
      expect(daysOn(12, 31, DateTime(2026, 12, 31)), 0);
      expect(daysOn(1, 2, DateTime(2026, 12, 31)), 2);
    });

    group('February 29', () {
      const leapDay = Birthday(month: 2, day: 29);

      test('is February 29 in a leap year', () {
        expect(days(leapDay, DateTime(2028, 2, 29)), 0);
        expect(days(leapDay, DateTime(2028, 2, 28)), 1);
        expect(days(leapDay, DateTime(2028, 2)), 28);
      });

      test('is celebrated on February 28 in a common year', () {
        expect(days(leapDay, DateTime(2027, 2, 28)), 0);
        expect(days(leapDay, DateTime(2027, 2, 27)), 1);
        expect(days(leapDay, DateTime(2026, 2)), 27);
      });

      test('March 1 of a common year waits for the next occurrence', () {
        // 2027 is common, 2028 is leap: February 29, 2028
        expect(days(leapDay, DateTime(2027, 3)), 365);
        // 2025 -> 2026, both common: February 28, 2026
        expect(days(leapDay, DateTime(2025, 3)), 364);
      });

      test('March 1 of a leap year waits for February 28 of the next year', () {
        expect(days(leapDay, DateTime(2028, 3)), 364);
      });

      test('December 2027 counts to February 29, 2028', () {
        expect(days(leapDay, DateTime(2027, 12, 31)), 60);
      });

      test('December 2028 counts to February 28, 2029', () {
        expect(days(leapDay, DateTime(2028, 12, 31)), 59);
      });
    });

    group('daylight saving time (Europe/Paris)', () {
      // Spring forward: Sunday March 29, 2026 (23 h day). Fall back: Sunday
      // October 25, 2026 (25 h day). The result only depends on the
      // calendar, whatever the time zone the tests run in.
      test('around the spring change', () {
        const b = Birthday(month: 3, day: 30);

        expect(days(b, DateTime(2026, 3, 28, 23, 30)), 2);
        expect(days(b, DateTime(2026, 3, 29)), 1);
        expect(days(b, DateTime(2026, 3, 29, 23, 59)), 1);
        expect(days(b, DateTime(2026, 3, 30)), 0);
      });

      test('a birthday on the spring change day', () {
        const b = Birthday(month: 3, day: 29);

        expect(days(b, DateTime(2026, 3, 27)), 2);
        expect(days(b, DateTime(2026, 3, 28, 23, 59)), 1);
        expect(days(b, DateTime(2026, 3, 29, 12)), 0);
      });

      test('around the fall change', () {
        const b = Birthday(month: 10, day: 26);

        expect(days(b, DateTime(2026, 10, 24, 23, 30)), 2);
        expect(days(b, DateTime(2026, 10, 25)), 1);
        expect(days(b, DateTime(2026, 10, 25, 23, 59)), 1);
        expect(days(b, DateTime(2026, 10, 26)), 0);
      });

      test('a countdown spanning a change counts calendar days', () {
        expect(daysOn(4, 5, DateTime(2026, 3, 20)), 16);
        expect(daysOn(11, 5, DateTime(2026, 10, 20)), 16);
      });
    });

    test('reads a UTC input on the local calendar', () {
      const b = Birthday(month: 3, day: 12);
      final local = DateTime(2026, 3, 7, 12);

      expect(days(b, local.toUtc()), days(b, local));
      expect(days(b, local.toUtc()), 5);
    });

    test('30 days is upcoming, 31 is not', () {
      const b = Birthday(month: 4, day: 11);

      expect(days(b, DateTime(2026, 3, 12)), 30);
      expect(days(b, DateTime(2026, 3, 11)), 31);
      expect(days(b, DateTime(2026, 3, 12)) <= Birthday.upcomingDays, isTrue);
      expect(days(b, DateTime(2026, 3, 11)) <= Birthday.upcomingDays, isFalse);
    });
  });
}
