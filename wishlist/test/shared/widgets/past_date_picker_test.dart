import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/widgets/past_date_picker.dart';

void main() {
  group('PastDatePicker.clampDay', () {
    final now = DateTime(2026, 10, 29, 15, 30);

    test('keeps the day of a date the wheels show', () {
      expect(
        PastDatePicker.clampDay(DateTime(2025, 12, 24, 8), now: now),
        DateTime(2025, 12, 24),
      );
    });

    test('brings a later day back to today', () {
      expect(
        PastDatePicker.clampDay(DateTime(2026, 10, 30), now: now),
        DateTime(2026, 10, 29),
      );
    });

    test('brings a day before the first year to its first day', () {
      expect(
        PastDatePicker.clampDay(DateTime(1999, 12, 31), now: now),
        DateTime(PastDatePicker.minimumYear),
      );
    });
  });
}
