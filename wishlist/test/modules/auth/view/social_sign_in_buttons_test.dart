import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:wishlist/app/config/config.dart';
import 'package:wishlist/modules/auth/view/auth_screen.dart';
import 'package:wishlist/shared/infra/auth_service.dart';

import '../../../pump_app.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  const googleConfig = GoogleSignInConfig(
    webClientId: 'web',
    iosClientId: 'ios',
  );

  setUpAll(() => registerFallbackValue(googleConfig));

  late _MockAuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authService = _MockAuthService();
    when(() => authService.signInWithGoogle(any()))
        .thenAnswer((_) async => true);
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
    expect(find.byType(SignInWithAppleButton), findsNothing);
    expect(find.text('ou'), findsNothing);
  });

  testWidgets('signs in with Google when configured', (tester) async {
    await pump(tester, config: googleConfig);

    expect(find.byType(SignInWithAppleButton), findsNothing);
    await tester.ensureVisible(find.text('Continuer avec Google'));
    await tester.tap(find.text('Continuer avec Google'));
    await tester.pumpAndSettle();

    verify(() => authService.signInWithGoogle(googleConfig)).called(1);
  });

  testWidgets('shows Apple then Google on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pump(tester, config: googleConfig);

      expect(find.byType(SignInWithAppleButton), findsOneWidget);
      expect(find.text('Continuer avec Google'), findsOneWidget);

      await tester.ensureVisible(find.byType(SignInWithAppleButton));
      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pumpAndSettle();

      verify(() => authService.signInWithApple()).called(1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('hides Google on iOS without the iOS client ID', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pump(
        tester,
        config: const GoogleSignInConfig(webClientId: 'web'),
      );

      expect(find.byType(SignInWithAppleButton), findsOneWidget);
      expect(find.text('Continuer avec Google'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shows an error when the sign-in fails', (tester) async {
    when(() => authService.signInWithGoogle(any()))
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
    verify(() => authService.signInWithGoogle(googleConfig)).called(2);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
