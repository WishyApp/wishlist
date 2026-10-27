import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/utils/get_wishlist_theme.dart';

import '../../../fixtures/fake_data.dart';

void main() {
  group('getWishlistTheme primaryColorDark', () {
    Color darkColorOf(Color color) => getWishlistTheme(
          null,
          fakeWishlist1.copyWith(color: AppColors.getHexValue(color)),
        ).primaryColorDark;

    for (final color in AppColors.colorPalette.keys) {
      test('keeps light content readable on ${AppColors.colorPalette[color]}',
          () {
        expect(
          AppColors.contrastRatio(darkColorOf(color), AppColors.background),
          greaterThanOrEqualTo(3),
        );
      });
    }

    test('only darkens the colors below the threshold (yellow)', () {
      for (final color in [AppColors.purple, AppColors.blue, AppColors.green]) {
        expect(darkColorOf(color), AppColors.darken(color));
      }
      expect(
        darkColorOf(AppColors.yellow),
        isNot(AppColors.darken(AppColors.yellow)),
      );
    });
  });
}
