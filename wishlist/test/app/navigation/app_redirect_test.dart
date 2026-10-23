import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:wishlist/app/navigation/app_redirect.dart';
import 'package:wishlist/shared/navigation/routes.dart';

import '../../fixtures/mock_supabase.dart';

Session _session({required bool hasPseudo}) {
  final user = MockUser();
  when(() => user.userMetadata)
      .thenReturn(hasPseudo ? {'pseudo': 'test'} : <String, dynamic>{});
  final session = MockSession();
  when(() => session.user).thenReturn(user);
  return session;
}

/// A router with the real redirect and a stub for each route.
GoRouter _router(String initialLocation, {required Session? session}) {
  GoRoute stub(String path) =>
      GoRoute(path: path, builder: (_, __) => const SizedBox());

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      stub(HomeRoute().location),
      stub(PseudoRoute().location),
      stub(BirthdayStepRoute().location),
      stub(AuthRoute().location),
      stub('/wishlist/1'),
    ],
    redirect: (context, state) => appRedirect(state, session: session),
  );
}

Future<String> _landing(
  WidgetTester tester,
  String initialLocation, {
  required Session? session,
}) async {
  final router = _router(initialLocation, session: session);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router.routeInformationProvider.value.uri.toString();
}

void main() {
  group('birthday step', () {
    testWidgets('a user with a pseudo can open it', (tester) async {
      final location = await _landing(
        tester,
        BirthdayStepRoute().location,
        session: _session(hasPseudo: true),
      );

      expect(location, '/birthday');
    });

    testWidgets('keeps its redirectTo', (tester) async {
      final location = await _landing(
        tester,
        birthdayStepLocation(redirectTo: '/wishlist/1'),
        session: _session(hasPseudo: true),
      );

      expect(location, '/birthday?redirectTo=%2Fwishlist%2F1');
    });

    testWidgets('a user without a pseudo is sent to the pseudo screen',
        (tester) async {
      final location = await _landing(
        tester,
        BirthdayStepRoute().location,
        session: _session(hasPseudo: false),
      );

      expect(location, '/pseudo');
    });

    testWidgets('a signed out user is sent to the auth screen', (tester) async {
      final location = await _landing(
        tester,
        BirthdayStepRoute().location,
        session: null,
      );

      expect(location.startsWith('/auth'), isTrue);
    });

    testWidgets('is not forced on a user with a pseudo opening home',
        (tester) async {
      final location = await _landing(
        tester,
        HomeRoute().location,
        session: _session(hasPseudo: true),
      );

      expect(location, '/');
    });
  });

  group('pseudo screen', () {
    testWidgets('stays there while the user has no pseudo', (tester) async {
      final location = await _landing(
        tester,
        PseudoRoute().location,
        session: _session(hasPseudo: false),
      );

      expect(location, '/pseudo');
    });

    testWidgets(
        'leads to the birthday step once the pseudo exists, keeping '
        'redirectTo', (tester) async {
      final location = await _landing(
        tester,
        '/pseudo?redirectTo=%2Fwishlist%2F1',
        session: _session(hasPseudo: true),
      );

      expect(location, '/birthday?redirectTo=%2Fwishlist%2F1');
    });

    testWidgets('leads to the birthday step without redirectTo',
        (tester) async {
      final location = await _landing(
        tester,
        PseudoRoute().location,
        session: _session(hasPseudo: true),
      );

      expect(location, '/birthday');
    });
  });

  group('auth screen', () {
    testWidgets('a signed in user with a pseudo goes home, not to the step',
        (tester) async {
      final location = await _landing(
        tester,
        AuthRoute().location,
        session: _session(hasPseudo: true),
      );

      expect(location, '/');
    });
  });
}
