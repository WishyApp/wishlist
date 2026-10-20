import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/auth/view/auth_screen.dart';
import 'package:wishlist/modules/auth/view/reset_password_screen.dart';
import 'package:wishlist/modules/settings/change_password/view/change_password_screen.dart';
import 'package:wishlist/shared/infra/auth_service.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/widgets/text_form_fields/input_password.dart';

import '../../../pump_app.dart';

class _MockAuthService extends Mock implements AuthService {}

class _FakeContext extends Fake implements BuildContext {}

class _FakeRef extends Fake implements WidgetRef {}

/// Passwords are never trimmed: what the user typed is what reaches the
/// service, otherwise a password with surrounding spaces locks the user out.
void main() {
  const password = ' Abcdef1! ';
  const oldPassword = ' OldPass1! ';

  setUpAll(() {
    registerFallbackValue(_FakeContext());
    registerFallbackValue(_FakeRef());
  });

  late _MockAuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authService = _MockAuthService();
    when(
      () => authService.signIn(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => authService.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => authService.resetPassword(newPassword: any(named: 'newPassword')),
    ).thenAnswer((_) async {});
    when(
      () => authService.signOut(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => authService.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    // The screens navigate on success: give them a router, with a page
    // below so that `pop` works.
    await tester.pumpRouterApp(
      '/screen',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SizedBox(),
          routes: [GoRoute(path: 'screen', builder: (_, __) => screen)],
        ),
      ],
      overrides: [authServiceProvider.overrideWithValue(authService)],
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterPasswords(WidgetTester tester, List<String> values) async {
    final fields = find.descendant(
      of: find.byType(InputPassword),
      matching: find.byType(TextFormField),
    );
    expect(fields, findsNWidgets(values.length));
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(fields.at(i), values[i]);
    }
  }

  testWidgets('sign-up sends the password as typed', (tester) async {
    await pump(tester, const AuthScreen());
    // First launch: the screen is in sign-up mode.
    await tester.enterText(find.byType(TextFormField).first, 'a@b.fr');
    await enterPasswords(tester, [password]);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    verify(() => authService.signUp(email: 'a@b.fr', password: password))
        .called(1);
  });

  testWidgets('sign-in sends the password as typed', (tester) async {
    await pump(tester, const AuthScreen());
    final l10n = tester.element(find.byType(AuthScreen)).l10n;
    await tester.tap(find.text(l10n.haveAccount));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'a@b.fr');
    await enterPasswords(tester, [password]);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    verify(() => authService.signIn(identifier: 'a@b.fr', password: password))
        .called(1);
  });

  testWidgets('reset sends the new password as typed', (tester) async {
    await pump(tester, const ResetPasswordScreen());
    await enterPasswords(tester, [password, password]);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    verify(() => authService.resetPassword(newPassword: password)).called(1);
  });

  testWidgets('change sends old and new passwords as typed', (tester) async {
    await pump(tester, const ChangePasswordScreen());
    await enterPasswords(tester, [oldPassword, password, password]);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    verify(
      () => authService.changePassword(
        oldPassword: oldPassword,
        newPassword: password,
      ),
    ).called(1);
  });

  testWidgets('revealed password is not altered by the keyboard',
      (tester) async {
    await pump(tester, const ResetPasswordScreen());
    await tester.tap(find.byIcon(Icons.visibility_off).first);
    await tester.pump();

    final field = tester.widget<TextField>(
      find
          .descendant(
            of: find.byType(InputPassword),
            matching: find.byType(TextField),
          )
          .first,
    );
    expect(field.obscureText, isFalse);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.smartDashesType, SmartDashesType.disabled);
    expect(field.smartQuotesType, SmartQuotesType.disabled);
  });

  testWidgets('confirmation compares raw values', (tester) async {
    await pump(tester, const ChangePasswordScreen());
    final l10n = tester.element(find.byType(ChangePasswordScreen)).l10n;
    await enterPasswords(tester, [oldPassword, password, 'Abcdef1!']);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(find.text(l10n.passwordsDoNotMatch), findsOneWidget);
    verifyNever(
      () => authService.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    );
  });
}
