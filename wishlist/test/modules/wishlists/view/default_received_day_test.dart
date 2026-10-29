import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/wishlists/view/default_received_day.dart';

void main() {
  final today = DateTime(2026, 12, 28, 15, 30);

  group('parseReceivedOn', () {
    test('reads a yyyy-MM-dd day as local midnight', () {
      expect(parseReceivedOn('2026-12-25'), DateTime(2026, 12, 25));
    });

    test('is null when absent, empty or malformed', () {
      expect(parseReceivedOn(null), isNull);
      expect(parseReceivedOn(''), isNull);
      expect(parseReceivedOn('noel'), isNull);
      expect(parseReceivedOn('2026-13-45'), isNull);
      expect(parseReceivedOn('2026-12-25T10:00:00'), isNull);
    });
  });

  group('formatReceivedOn', () {
    test('writes the day as yyyy-MM-dd', () {
      expect(formatReceivedOn(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    });
  });

  group('defaultReceivedDay', () {
    final wishCreated = [DateTime(2026, 11, 2)];

    test('is today without a party day (today behaviour)', () {
      expect(
        defaultReceivedDay(
          receivedOn: null,
          now: today,
          wishCreatedAts: wishCreated,
        ),
        isNull,
      );
    });

    test('is the party day when it is past and after the wishes', () {
      expect(
        defaultReceivedDay(
          receivedOn: DateTime(2026, 12, 25),
          now: today,
          wishCreatedAts: wishCreated,
        ),
        DateTime(2026, 12, 25),
      );
    });

    test('never goes into the future', () {
      expect(
        defaultReceivedDay(
          receivedOn: DateTime(2027, 1, 3),
          now: today,
          wishCreatedAts: wishCreated,
        ),
        DateTime(2026, 12, 28),
      );
    });

    test('never goes before the creation day of a wish', () {
      expect(
        defaultReceivedDay(
          receivedOn: DateTime(2026, 12, 25),
          now: today,
          wishCreatedAts: [DateTime(2026, 11, 2), DateTime(2026, 12, 26, 9)],
        ),
        DateTime(2026, 12, 26),
      );
    });

    test('a creation day after today still ends on today', () {
      expect(
        defaultReceivedDay(
          receivedOn: DateTime(2026, 12, 25),
          now: today,
          wishCreatedAts: [DateTime(2026, 12, 30)],
        ),
        DateTime(2026, 12, 28),
      );
    });
  });
}
