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
}
