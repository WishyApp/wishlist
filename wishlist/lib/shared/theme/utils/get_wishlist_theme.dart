import 'package:flutter/material.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/theme.dart';

ThemeData getWishlistTheme(BuildContext? context, Wishlist wishlist) {
  final wishlistColor = AppColors.getColorFromHexValue(wishlist.color);
  // Fond du centre du bouton « + » et de la carte de sélection, sous un texte
  // ou une icône clairs : foncé encore si besoin pour un contraste de 3:1, le
  // minimum WCAG pour une icône ou un texte en gras (seul le jaune est foncé)
  final wishlistDarkColor = AppColors.darkenForContrast(
    AppColors.darken(wishlistColor),
    foreground: AppColors.background,
    minContrast: 3,
  );

  final currentTheme = context != null ? Theme.of(context) : theme;

  return currentTheme.copyWith(
    primaryColor: wishlistColor,
    primaryColorDark: wishlistDarkColor,
    appBarTheme: currentTheme.appBarTheme.copyWith(
      backgroundColor: wishlistColor,
    ),
    progressIndicatorTheme: currentTheme.progressIndicatorTheme.copyWith(
      color: wishlistColor,
    ),
    textSelectionTheme: currentTheme.textSelectionTheme.copyWith(
      cursorColor: wishlistColor,
      selectionHandleColor: wishlistColor,
      selectionColor: wishlistColor.withValues(alpha: 0.3),
    ),
  );
}
