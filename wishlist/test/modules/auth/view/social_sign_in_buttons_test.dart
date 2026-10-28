import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishlist/app/config/config.dart';
import 'package:wishlist/modules/auth/view/auth_screen.dart';
import 'package:wishlist/shared/infra/auth_service.dart';

import '../../../pump_app.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  const googleConfig = GoogleSignInConfig(webClientId: 'web');

  late _MockAuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authService = _MockAuthService();
    when(() => authService.signInWithGoogle()).thenAnswer((_) async => true);
    when(() => authService.signInWithApple()).thenAnswer((_) async => true);
  });

  Future<void> pump(
    WidgetTester tester, {
    GoogleSignInConfig? config,
  }) async {
    await tester.pumpRouterApp(
      '/auth',
      routes: [
        GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      ],
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        googleSignInConfigProvider.overrideWithValue(config),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows no social button on Android without Google config',
      (tester) async {
    await pump(tester);

    expect(find.text('Continuer avec Google'), findsNothing);
    expect(find.text('Continuer avec Apple'), findsNothing);
    expect(find.text('ou'), findsNothing);
  });

  testWidgets('signs in with Google when configured', (tester) async {
    await pump(tester, config: googleConfig);

    expect(find.text('Continuer avec Apple'), findsNothing);
    await tester.ensureVisible(find.text('Continuer avec Google'));
    await tester.tap(find.text('Continuer avec Google'));
    await tester.pumpAndSettle();

    verify(() => authService.signInWithGoogle()).called(1);
  });

  testWidgets('shows Apple then Google on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pump(tester, config: googleConfig);

      expect(find.text('Continuer avec Apple'), findsOneWidget);
      expect(find.text('Continuer avec Google'), findsOneWidget);

      await tester.ensureVisible(find.text('Continuer avec Apple'));
      await tester.tap(find.text('Continuer avec Apple'));
      await tester.pumpAndSettle();

      verify(() => authService.signInWithApple()).called(1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shows an error when the sign-in fails', (tester) async {
    when(() => authService.signInWithGoogle())
        .thenThrow(Exception('misconfigured'));
    await pump(tester, config: googleConfig);

    await tester.ensureVisible(find.text('Continuer avec Google'));
    await tester.tap(find.text('Continuer avec Google'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Une erreur'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // The buttons are usable again for another attempt.
    await tester.tap(find.text('Continuer avec Google'));
    await tester.pump();
    verify(() => authService.signInWithGoogle()).called(2);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('disables the links while a social sign-in is running',
      (tester) async {
    final signIn = Completer<bool>();
    when(() => authService.signInWithGoogle()).thenAnswer((_) => signIn.future);
    await pump(tester, config: googleConfig);

    await tester.ensureVisible(find.text('Continuer avec Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer avec Google'));
    await tester.pump();

    for (final link in ['Mot de passe oublié ?', 'Vous avez déjà un compte']) {
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.textContaining(link),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.onPressed, isNull, reason: link);
    }

    signIn.complete(false);
    await tester.pumpAndSettle();
  });
}
