import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/widgets/password_strength_indicator.dart';
import 'package:wishlist/shared/widgets/text_form_fields/input_password.dart';

import '../../../pump_app.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<void> pump(
    WidgetTester tester, {
    required bool deferStrengthIndicator,
    bool showStrengthIndicator = true,
  }) async {
    await tester.pumpApp(
      Column(
        children: [
          InputPassword(
            autofillHints: AutofillHints.newPassword,
            controller: controller,
            label: 'Mot de passe',
            textInputAction: TextInputAction.done,
            showStrengthIndicator: showStrengthIndicator,
            deferStrengthIndicator: deferStrengthIndicator,
          ),
          // Somewhere to move the focus to.
          const TextField(key: Key('other')),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the strength indicator right away by default',
      (tester) async {
    await pump(tester, deferStrengthIndicator: false);

    expect(find.byType(PasswordStrengthIndicator), findsOneWidget);
  });

  group('deferStrengthIndicator', () {
    testWidgets('hides the indicator until the field is focused',
        (tester) async {
      await pump(tester, deferStrengthIndicator: true);
      expect(find.byType(PasswordStrengthIndicator), findsNothing);

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      expect(find.byType(PasswordStrengthIndicator), findsOneWidget);
    });

    testWidgets('keeps the indicator once the field holds a password',
        (tester) async {
      await pump(tester, deferStrengthIndicator: true);
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.tap(find.byKey(const Key('other')));
      await tester.pumpAndSettle();

      expect(find.byType(PasswordStrengthIndicator), findsOneWidget);
    });

    testWidgets('hides the indicator again when left empty', (tester) async {
      await pump(tester, deferStrengthIndicator: true);
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('other')));
      await tester.pumpAndSettle();

      expect(find.byType(PasswordStrengthIndicator), findsNothing);
    });

    testWidgets('shows the indicator for a password filled by autofill',
        (tester) async {
      await pump(tester, deferStrengthIndicator: true);

      controller.text = 'Generated-Strong-1';
      await tester.pumpAndSettle();

      expect(find.byType(PasswordStrengthIndicator), findsOneWidget);
    });

    testWidgets('never shows the indicator when it is disabled',
        (tester) async {
      await pump(
        tester,
        deferStrengthIndicator: true,
        showStrengthIndicator: false,
      );
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pumpAndSettle();

      expect(find.byType(PasswordStrengthIndicator), findsNothing);
    });

    testWidgets(
        'hides the indicator when enabled while focused, then left empty',
        (tester) async {
      // Sign-in to sign-up with the empty password field focused: the
      // parent enables the indicator on the same element.
      final showIndicator = ValueNotifier(false);
      addTearDown(showIndicator.dispose);
      await tester.pumpApp(
        ValueListenableBuilder(
          valueListenable: showIndicator,
          builder: (context, show, _) => Column(
            children: [
              InputPassword(
                autofillHints: AutofillHints.password,
                controller: controller,
                label: 'Mot de passe',
                textInputAction: TextInputAction.done,
                showStrengthIndicator: show,
                deferStrengthIndicator: true,
              ),
              const TextField(key: Key('other')),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      showIndicator.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(PasswordStrengthIndicator), findsOneWidget);

      await tester.tap(find.byKey(const Key('other')));
      await tester.pumpAndSettle();

      expect(find.byType(PasswordStrengthIndicator), findsNothing);
    });
  });
}
