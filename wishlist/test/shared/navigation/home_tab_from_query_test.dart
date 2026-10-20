import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';
import 'package:wishlist/shared/navigation/routes.dart';

void main() {
  group('homeTabFromQuery', () {
    test('defaults to the home tab when missing or empty', () {
      expect(homeTabFromQuery(null), FloatingNavBarTab.home);
      expect(homeTabFromQuery(''), FloatingNavBarTab.home);
    });

    test('returns the tab at the given index', () {
      expect(homeTabFromQuery('1'), FloatingNavBarTab.friends);
      expect(homeTabFromQuery('2'), FloatingNavBarTab.bookedWishes);
    });

    test('falls back to the home tab for invalid values', () {
      expect(homeTabFromQuery('9'), FloatingNavBarTab.home);
      expect(homeTabFromQuery('-1'), FloatingNavBarTab.home);
      expect(homeTabFromQuery('abc'), FloatingNavBarTab.home);
    });
  });
}
