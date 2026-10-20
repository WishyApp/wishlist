import 'package:flutter/material.dart';

/// Texte qui réduit sa taille de police pour que son mot le plus long tienne
/// sur une seule ligne (un mot composé peut toujours passer à la ligne après
/// son trait d'union), à la manière de `minimumScaleFactor` (iOS) ou
/// `autoSizeText` (Android).
///
/// Les retours à la ligne entre les mots, `maxLines` et `overflow` restent
/// ceux d'un [Text] classique. Sous [minScale], la taille n'est plus réduite
/// et Flutter coupe le mot comme avant, plutôt que d'afficher un texte
/// illisible.
class WordFitText extends StatelessWidget {
  const WordFitText(
    this.text, {
    super.key,
    this.style,
    this.minScale = 0.6,
    this.maxLines,
    this.overflow,
  }) : assert(
          minScale > 0 && minScale <= 1,
          'minScale must be in ]0, 1]',
        );

  final String text;
  final TextStyle? style;

  /// Plus petit ratio appliqué à la taille de police de base.
  final double minScale;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Pas de réduction de la taille de police, en sp.
  static const double _step = 0.5;

  /// Points où le moteur de texte peut passer à la ligne sans couper un mot :
  /// les espaces, et après un trait d'union suivi d'une lettre
  /// (« Saint-|Valentin », mais pas « Noël-2026 », que l'algorithme Unicode
  /// garde d'un seul tenant).
  static final RegExp _breakOpportunity =
      RegExp(r'\s+|(?<=-)(?=\p{L})', unicode: true);

  @override
  Widget build(BuildContext context) {
    var effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    // Même règle que [Text] : le texte en gras de l'accessibilité élargit
    // les glyphes, il faut donc mesurer avec.
    if (MediaQuery.boldTextOf(context)) {
      effectiveStyle = effectiveStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = _fittingFontSize(
          style: effectiveStyle,
          textScaler: textScaler,
          textDirection: textDirection,
          maxWidth: constraints.maxWidth,
        );

        return Text(
          text,
          style: style?.copyWith(fontSize: fontSize) ??
              TextStyle(fontSize: fontSize),
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }

  double? _fittingFontSize({
    required TextStyle style,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required double maxWidth,
  }) {
    final words = text.split(_breakOpportunity).where((w) => w.isNotEmpty);
    if (words.isEmpty || !maxWidth.isFinite) {
      return style.fontSize;
    }

    final baseSize = style.fontSize ?? 14;

    double measure(String word, double size) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style.copyWith(fontSize: size)),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // Le mot le plus large (pas forcément le plus long en caractères).
    var widest = words.first;
    var baseWidth = measure(widest, baseSize);
    for (final word in words.skip(1)) {
      final width = measure(word, baseSize);
      if (width > baseWidth) {
        widest = word;
        baseWidth = width;
      }
    }
    if (baseWidth <= maxWidth) {
      return style.fontSize;
    }

    final minSize = baseSize * minScale;
    var size =
        (baseSize * maxWidth / baseWidth / _step).floorToDouble() * _step;
    // La largeur n'est pas strictement proportionnelle à la taille (crénage,
    // arrondis) : on descend jusqu'à ce que le mot tienne vraiment.
    while (size > minSize && measure(widest, size) > maxWidth) {
      size -= _step;
    }
    // Sous le plancher, on s'arrête à minScale : Flutter coupe alors le mot.
    return size < minSize ? minSize : size;
  }
}
