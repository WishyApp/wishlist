import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/shared/utils/relative_date_utils.dart';

void main() {
  final l10n = AppLocalizationsFr();
  final now = DateTime(2026, 10, 23, 9);

  // The tests only load the en_US date symbols (see flutter_test_config.dart)
  String format(DateTime date) =>
      formatRelativeDate(l10n, date, now: now, locale: 'en_US');

  test('counts calendar days, not 24 h periods', () {
    expect(format(DateTime(2026, 10, 23, 0, 5)), "Aujourd'hui");
    expect(format(DateTime(2026, 10, 22, 23, 55)), 'Hier');
    expect(format(DateTime(2026, 10, 20, 10)), 'Il y a 3 jours');
  });

  test('a date in the future reads as today', () {
    expect(format(DateTime(2026, 10, 24)), "Aujourd'hui");
  });

  test('switches to weeks from 7 days', () {
    expect(format(DateTime(2026, 10, 17)), 'Il y a 6 jours');
    expect(format(DateTime(2026, 10, 16)), 'Il y a 1 semaine');
    expect(format(DateTime(2026, 10, 2)), 'Il y a 3 semaines');
    expect(format(DateTime(2026, 9, 24)), 'Il y a 4 semaines');
  });

  test('shows the month from 30 days, with the year when it differs', () {
    expect(format(DateTime(2026, 9, 23)), 'September');
    expect(format(DateTime(2025, 12, 25)), 'Dec 2025');
  });
}
