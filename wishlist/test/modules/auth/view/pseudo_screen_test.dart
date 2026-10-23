import 'dart:async';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;
import 'package:wishlist/app/navigation/app_redirect.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/auth/view/pseudo_screen.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/theme.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Profile(id: 'id', pseudo: 'pseudo'));
  });

  testAdaptiveWidgets('$PseudoScreen golden test', (tester, variant) async {
    await tester.pumpRouterApp(
      PseudoRoute().location,
      windowConfig: variant,
      overrides: pseudoScreenOverrides(),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<PseudoScreen>(variant);
  });

  group('on success', () {
    late MockUserService userService;

    setUp(() {
      userService = MockUserService();
      when(() => userService.createUserProfile(any())).thenAnswer((_) async {});
    });

    /// Submits the pseudo and returns the location of the birthday step.
    Future<String?> submit(WidgetTester tester, {String? redirectTo}) async {
      String? reached;
      await tester.pumpRouterApp(
        PseudoRoute().location,
        overrides: [
          ...pseudoScreenOverrides(),
          userServiceProvider.overrideWithValue(userService),
        ],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Text('home-stub'),
            routes: [
              GoRoute(
                path: 'pseudo',
                builder: (_, __) => PseudoScreen(redirectTo: redirectTo),
              ),
              GoRoute(
                path: 'birthday',
                builder: (_, state) {
                  reached = state.uri.toString();
                  return const Text('birthday-stub');
                },
              ),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      return reached;
    }

    testWidgets('goes to the birthday step', (tester) async {
      expect(await submit(tester), '/birthday');
      expect(find.text('home-stub'), findsNothing);
      verify(() => userService.createUserProfile(any())).called(1);
    });

    testWidgets('keeps redirectTo for the birthday step', (tester) async {
      expect(
        await submit(tester, redirectTo: '/wishlist/1'),
        '/birthday?redirectTo=%2Fwishlist%2F1',
      );
    });

    testWidgets(
        'with the real redirect, the session gaining the pseudo lands on the '
        'step with redirectTo', (tester) async {
      var hasPseudo = false;
      final events = StreamController<AuthState>.broadcast();
      addTearDown(events.close);
      final notifier = AuthStateNotifier(events.stream);
      addTearDown(notifier.dispose);
      final session = MockSession();
      final user = MockUser();
      when(() => session.user).thenReturn(user);
      when(() => user.userMetadata)
          .thenAnswer((_) => hasPseudo ? {'pseudo': 'Alice'} : {});
      // Like createUserProfile: the session is refreshed, which emits an event
      when(() => userService.createUserProfile(any())).thenAnswer((_) async {
        hasPseudo = true;
        events.add(const AuthState(AuthChangeEvent.tokenRefreshed, null));
      });

      final router = GoRouter(
        initialLocation: '/pseudo?redirectTo=%2Fwishlist%2F1',
        refreshListenable: notifier,
        redirect: (_, state) => appRedirect(state, session: session),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('home-stub')),
          GoRoute(
            path: '/pseudo',
            builder: (_, state) => PseudoScreen(
              redirectTo: state.uri.queryParameters['redirectTo'],
            ),
          ),
          GoRoute(
            path: '/birthday',
            builder: (_, __) => const Text('birthday-stub'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...pseudoScreenOverrides(),
            userServiceProvider.overrideWithValue(userService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('birthday-stub'), findsOneWidget);
      expect(find.text('home-stub'), findsNothing);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/birthday?redirectTo=%2Fwishlist%2F1',
      );
    });
  });
}
