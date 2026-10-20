import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/widgets/word_fit_text.dart';

// Les tests utilisent la police Ahem : chaque glyphe fait 1 em de large.
const _base = TextStyle(fontSize: 22, fontWeight: FontWeight.w800);

Future<void> _pump(
  WidgetTester tester,
  String text, {
  double width = 200,
  double minScale = 0.6,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: WordFitText(
              text,
              style: _base,
              minScale: minScale,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    ),
  );
}

double _fontSize(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style!.fontSize!;

RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byType(Text));

void main() {
  testWidgets('shrinks a long single word so it stays on one line',
      (tester) async {
    await _pump(tester, 'Anniversaire');

    final size = _fontSize(tester);
    expect(size, lessThan(22));
    expect(size, greaterThanOrEqualTo(22 * 0.6));
    expect(_lineCount(tester), 1);
    expect(_paragraph(tester).size.width, lessThanOrEqualTo(200));
  });

  testWidgets('keeps the base size for a short title', (tester) async {
    await _pump(tester, 'Noël');

    expect(_fontSize(tester), 22);
  });

  testWidgets('keeps wrapping between words at the base size', (tester) async {
    await _pump(tester, 'Mon super cadeau', width: 150);

    expect(_fontSize(tester), 22);
    expect(_lineCount(tester), greaterThan(1));
  });

  testWidgets('lets a hyphenated compound wrap after the hyphen',
      (tester) async {
    await _pump(tester, 'Saint-Valentin');

    expect(_fontSize(tester), 22);
    expect(_lineCount(tester), 2);
  });

  testWidgets('keeps a hyphen followed by a digit unbroken', (tester) async {
    await _pump(tester, 'Noël-2026', width: 150);

    expect(_fontSize(tester), lessThan(22));
    expect(_lineCount(tester), 1);
  });

  testWidgets('keeps a word and its spaced French punctuation together',
      (tester) async {
    // Unicode interdit la coupure avant « ! », même après une espace.
    await _pump(tester, 'Anniversaire !');

    expect(_fontSize(tester), lessThan(22));
    expect(_lineCount(tester), 1);
    expect(_paragraph(tester).size.width, lessThanOrEqualTo(200));
  });

  testWidgets('does not break at a no-break space', (tester) async {
    await _pump(tester, 'Noël\u00A0!', width: 100);

    expect(_fontSize(tester), lessThan(22));
    expect(_lineCount(tester), 1);
  });

  testWidgets('lets a compound wrap after an en dash', (tester) async {
    await _pump(tester, 'Saint\u2013Valentin');

    expect(_fontSize(tester), 22);
    expect(_lineCount(tester), 2);
  });

  testWidgets('stops at minScale for a very long word', (tester) async {
    await _pump(tester, 'Anticonstitutionnellement');

    expect(_fontSize(tester), closeTo(22 * 0.6, 0.0001));
  });

  testWidgets('honors a custom minScale', (tester) async {
    await _pump(tester, 'Anticonstitutionnellement', minScale: 0.5);

    expect(_fontSize(tester), closeTo(22 * 0.5, 0.0001));
  });

  testWidgets('takes the text scaler into account', (tester) async {
    await _pump(tester, 'Fête', width: 140);
    final unscaled = _fontSize(tester);

    await _pump(tester, 'Fête', width: 140, textScale: 2);
    final scaled = _fontSize(tester);

    expect(unscaled, 22);
    expect(scaled, lessThan(22));
    expect(_lineCount(tester), 1);
  });
}

int _lineCount(WidgetTester tester) {
  final paragraph = _paragraph(tester);
  final length = tester.widget<Text>(find.byType(Text)).data!.length;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  );
  return boxes.map((box) => box.top.round()).toSet().length;
}
