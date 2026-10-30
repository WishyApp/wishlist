import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/wishlists/view/default_received_day.dart';

void main() {
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
}
