import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/theme/colors.dart';

void main() {
  group('AppColors.contrastRatio', () {
    test('is 21 between black and white, whatever the order', () {
      expect(
        AppColors.contrastRatio(Colors.black, Colors.white),
        closeTo(21, 0.01),
      );
      expect(
        AppColors.contrastRatio(Colors.white, Colors.black),
        closeTo(21, 0.01),
      );
    });

    test('is 1 between a color and itself', () {
      expect(
        AppColors.contrastRatio(AppColors.purple, AppColors.purple),
        1,
      );
    });
  });

  group('AppColors.darkenForContrast', () {
    // Les couleurs foncées des wishlists, comme dans getWishlistTheme
    for (final color in AppColors.colorPalette.keys) {
      test('makes light text readable on ${AppColors.colorPalette[color]}', () {
        final adjusted = AppColors.darkenForContrast(
          AppColors.darken(color),
          foreground: AppColors.background,
        );

        expect(
          AppColors.contrastRatio(adjusted, AppColors.background),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    test('keeps a color that is already dark enough', () {
      final darkPurple = AppColors.darken(AppColors.purple);

      expect(
        AppColors.darkenForContrast(
          darkPurple,
          foreground: AppColors.background,
        ),
        darkPurple,
      );
    });

    test('darkens no more than needed', () {
      final adjusted = AppColors.darkenForContrast(
        AppColors.darken(AppColors.yellow),
        foreground: AppColors.background,
      );

      // One step lighter would not be readable
      expect(
        AppColors.contrastRatio(
          AppColors.lighten(adjusted, 1 / 0.95),
          AppColors.background,
        ),
        lessThan(4.5),
      );
    });
  });
}
