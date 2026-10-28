import 'dart:math';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFFF7F6F0);

  static const Color primary = Color(0xFFF28C57);

  static const Color darkOrange = Color(0xFFDF733D);

  static const Color darkGrey = Color(0xFF2C2C2C);

  static const Color blue = Color(0xFF69ABE9);

  static const Color purple = Color(0xFF9665E5);

  static const Color yellow = Color(0xFFDBCD4D);

  static const Color green = Color(0xFF57BD87);

  static const Color gainsboro = Color(0xFFE8E4DA);

  static const Color pastelGray = Color(0xFFD3CBC1);

  static const Color makara = Color(0xFF887A6B);

  static const Color favorite = Color(0xFFFF675C);

  /// Destructive actions and errors written as text: dark enough to be read
  /// on [background] and [gainsboro].
  static const Color danger = Color(0xFFC62828);

  static final Map<Color, String> colorPalette = {
    blue: 'blue',
    purple: 'purple',
    yellow: 'yellow',
    green: 'green',
  };

  static Color getRandomColor() {
    final random = Random();
    final colors = colorPalette.keys.toList();
    final index = random.nextInt(colors.length);
    return colors[index];
  }

  static Color darken(Color color, [double factor = 0.8]) {
    final red = color.r * factor;
    final green = color.g * factor;
    final blue = color.b * factor;

    return Color.from(alpha: color.a, red: red, green: green, blue: blue);
  }

  /// Rapport de contraste WCAG entre deux couleurs, de 1 à 21
  static double contrastRatio(Color a, Color b) {
    final luminanceA = a.computeLuminance();
    final luminanceB = b.computeLuminance();

    return (max(luminanceA, luminanceB) + 0.05) /
        (min(luminanceA, luminanceB) + 0.05);
  }

  /// Fonce [color] par petits pas jusqu'à ce que [foreground] y soit lisible
  /// ([minContrast] : 4.5, le minimum WCAG AA pour un texte normal). Une
  /// couleur déjà assez foncée est rendue telle quelle.
  static Color darkenForContrast(
    Color color, {
    required Color foreground,
    double minContrast = 4.5,
  }) {
    var result = color;
    // Le noir contraste à plus de 18:1 avec un texte clair : la boucle
    // s'arrête bien avant la limite
    for (var step = 0;
        step < 50 && contrastRatio(result, foreground) < minContrast;
        step++) {
      result = darken(result, 0.95);
    }

    return result;
  }

  static Color lighten(Color color, [double factor = 1.07]) {
    final red = color.r * factor;
    final green = color.g * factor;
    final blue = color.b * factor;

    return Color.from(alpha: color.a, red: red, green: green, blue: blue);
  }

  static String getHexValue(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2)}';
  }

  static Color getColorFromHexValue(String hexColor) {
    return Color(int.parse(hexColor.substring(1, 7), radix: 16) + 0xFF000000);
  }
}
