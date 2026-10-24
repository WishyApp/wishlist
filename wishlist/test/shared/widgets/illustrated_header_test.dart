import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/widgets/illustrated_header.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  const illustration = SizedBox(key: Key('illustration'), height: 100);

  testWidgets('shows the illustration, the title and the description',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const IllustratedHeader(
          illustration: illustration,
          title: 'Title',
          description: 'Description',
        ),
      ),
    );

    expect(find.byKey(const Key('illustration')), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    final title = tester.widget<Text>(find.text('Title'));
    expect(title.style, AppTextStyles.title);
    expect(title.textAlign, TextAlign.center);

    final description = tester.widget<Text>(find.text('Description'));
    expect(description.style?.color, AppColors.makara);
    expect(description.textAlign, TextAlign.center);

    expect(
      tester.getTopLeft(find.text('Title')).dy -
          tester.getBottomLeft(find.byKey(const Key('illustration'))).dy,
      32,
    );
  });

  testWidgets('omits the description when there is none', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const IllustratedHeader(
          illustration: illustration,
          title: 'Title',
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('applies the custom styles and gaps', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const IllustratedHeader(
          illustration: illustration,
          title: 'Title',
          titleStyle: AppTextStyles.titleSmall,
          description: 'Description',
          descriptionStyle: AppTextStyles.smaller,
          illustrationGap: 16,
          titleGap: 4,
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Title')).style,
      AppTextStyles.titleSmall,
    );
    expect(
      tester.widget<Text>(find.text('Description')).style,
      AppTextStyles.smaller.copyWith(color: AppColors.makara),
    );
    expect(
      tester.getTopLeft(find.text('Title')).dy -
          tester.getBottomLeft(find.byKey(const Key('illustration'))).dy,
      16,
    );
    expect(
      tester.getTopLeft(find.text('Description')).dy -
          tester.getBottomLeft(find.text('Title')).dy,
      4,
    );
  });
}
