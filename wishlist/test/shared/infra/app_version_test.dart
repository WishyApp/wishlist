import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/infra/app_version.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('parses major.minor.patch', () {
      expect(AppVersion.tryParse('0.3.0'), const AppVersion(0, 3, 0));
      expect(AppVersion.tryParse('12.0.7'), const AppVersion(12, 0, 7));
    });

    test('missing parts count as 0', () {
      expect(AppVersion.tryParse('1.2'), const AppVersion(1, 2, 0));
      expect(AppVersion.tryParse('3'), const AppVersion(3, 0, 0));
    });

    test('ignores whitespace, build and pre-release suffixes', () {
      expect(AppVersion.tryParse(' 0.3.0 '), const AppVersion(0, 3, 0));
      expect(AppVersion.tryParse('0.3.0+10'), const AppVersion(0, 3, 0));
      expect(AppVersion.tryParse('1.0.0-beta.1'), const AppVersion(1, 0, 0));
    });

    test('returns null for anything else', () {
      for (final value in [
        null,
        '',
        ' ',
        'abc',
        'v1.0.0',
        '1.x.0',
        '1..0',
        '1.0.',
        '.1',
        '1.2.3.4',
        '-1.0.0',
        '1.-2.0',
        '99999999999999999999.0.0',
      ]) {
        expect(AppVersion.tryParse(value), isNull, reason: '$value');
      }
    });
  });

  group('compare', () {
    int compare(String a, String b) =>
        AppVersion.tryParse(a)!.compareTo(AppVersion.tryParse(b)!);

    test('is numeric, not lexicographic', () {
      expect(compare('0.10.0', '0.3.0'), greaterThan(0));
      expect(compare('0.3.0', '0.10.0'), lessThan(0));
      expect(compare('1.0.10', '1.0.9'), greaterThan(0));
      expect(compare('10.0.0', '9.99.99'), greaterThan(0));
    });

    test('equal versions, including padded ones', () {
      expect(compare('0.3.0', '0.3.0'), 0);
      expect(compare('1.2', '1.2.0'), 0);
      expect(compare('0.3.0+10', '0.3.0'), 0);
    });

    test('operator <', () {
      final v030 = AppVersion.tryParse('0.3.0')!;
      expect(v030 < AppVersion.tryParse('0.10.0')!, isTrue);
      expect(v030 < AppVersion.tryParse('0.3')!, isFalse);
    });
  });
}
