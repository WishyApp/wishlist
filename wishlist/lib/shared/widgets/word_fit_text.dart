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

  /// Coupures après un tiret suivi d'une lettre (« Saint-|Valentin »), que
  /// [TextPainter.minIntrinsicWidth] ignore alors que le rendu les utilise.
  /// Pas devant un chiffre (« Noël-2026 » reste d'un seul tenant), ni après
  /// un tiret en début de mot (« -Valentin »).
  static final RegExp _dashBreak =
      RegExp(r'(?<=\p{L}[-\u2010\u2013])(?=\p{L})', unicode: true);

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
    // Même locale que [RichText], qui influe sur les règles de coupure.
    final locale = Localizations.maybeLocaleOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = _fittingFontSize(
          style: effectiveStyle,
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
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
    required Locale? locale,
    required double maxWidth,
  }) {
    if (!maxWidth.isFinite) {
      return style.fontSize;
    }

    final baseSize = style.fontSize ?? 14;

    final segments = text.split(_dashBreak);

    // Largeur du plus large segment insécable. Hors tirets, le moteur
    // applique lui-même les règles Unicode (UAX #14) : pas de coupure avant
    // « ! » ni à une espace insécable (« Anniversaire ! », « Noël ! »).
    double widestUnbreakable(double size) {
      final painter = TextPainter(
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
      );
      var widest = 0.0;
      for (final segment in segments) {
        painter
          ..text = TextSpan(
            text: segment,
            style: style.copyWith(fontSize: size),
          )
          ..layout();
        if (painter.minIntrinsicWidth > widest) {
          widest = painter.minIntrinsicWidth;
        }
      }
      painter.dispose();
      return widest;
    }

    final baseWidth = widestUnbreakable(baseSize);
    if (baseWidth <= maxWidth) {
      return style.fontSize;
    }

    final minSize = baseSize * minScale;
    var size =
        (baseSize * maxWidth / baseWidth / _step).floorToDouble() * _step;
    // La largeur n'est pas strictement proportionnelle à la taille (crénage,
    // arrondis) : on descend jusqu'à ce que le segment tienne vraiment.
    while (size > minSize && widestUnbreakable(size) > maxWidth) {
      size -= _step;
    }
    // Sous le plancher, on s'arrête à minScale : Flutter coupe alors le mot.
    return size < minSize ? minSize : size;
  }
}
