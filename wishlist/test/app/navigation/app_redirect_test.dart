import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:wishlist/app/navigation/app_redirect.dart';
import 'package:wishlist/shared/navigation/pseudo_creation_marker.dart';
import 'package:wishlist/shared/navigation/redirect_target.dart';
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
      stub('/settings'),
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
  setUp(pseudoCreationMarker.clear);

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
        locationWithRedirectTo(BirthdayStepRoute().location, '/wishlist/1'),
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

  group('redirectTo', () {
    testWidgets('an unsafe one is dropped on the way to the step',
        (tester) async {
      pseudoCreationMarker.mark();
      final location = await _landing(
        tester,
        '/pseudo?redirectTo=%2F%2Fevil.com%2Fx',
        session: _session(hasPseudo: true),
      );

      expect(location, '/birthday');
    });

    testWidgets('a wishy deep link is reduced to its path', (tester) async {
      final deepLink = Uri.encodeQueryComponent(
        'wishy://com.raphtang.wishy/wishlist/1?x=1',
      );
      pseudoCreationMarker.mark();
      final location = await _landing(
        tester,
        '/pseudo?redirectTo=$deepLink',
        session: _session(hasPseudo: true),
      );

      expect(location, '/birthday?redirectTo=%2Fwishlist%2F1%3Fx%3D1');
    });

    testWidgets('an unsafe one on the step is left to the screen',
        (tester) async {
      final location = await _landing(
        tester,
        '/birthday?redirectTo=%2F%2Fevil.com%2Fx',
        session: _session(hasPseudo: true),
      );

      expect(location, '/birthday?redirectTo=%2F%2Fevil.com%2Fx');
    });
  });

  group('a user with a pseudo (a token refresh never forces the step)', () {
    testWidgets('stays on settings', (tester) async {
      final location = await _landing(
        tester,
        '/settings',
        session: _session(hasPseudo: true),
      );

      expect(location, '/settings');
    });

    testWidgets('stays on a wishlist', (tester) async {
      final location = await _landing(
        tester,
        '/wishlist/1',
        session: _session(hasPseudo: true),
      );

      expect(location, '/wishlist/1');
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
        'leads to the birthday step once the pseudo was just created, keeping '
        'redirectTo', (tester) async {
      pseudoCreationMarker.mark();
      final location = await _landing(
        tester,
        '/pseudo?redirectTo=%2Fwishlist%2F1',
        session: _session(hasPseudo: true),
      );

      expect(location, '/birthday?redirectTo=%2Fwishlist%2F1');
    });

    testWidgets(
        'an existing pseudo on /pseudo goes to redirectTo, not the step',
        (tester) async {
      final location = await _landing(
        tester,
        '/pseudo?redirectTo=%2Fwishlist%2F1',
        session: _session(hasPseudo: true),
      );

      expect(location, '/wishlist/1');
    });

    testWidgets('an existing pseudo on /pseudo goes home without redirectTo',
        (tester) async {
      final location = await _landing(
        tester,
        PseudoRoute().location,
        session: _session(hasPseudo: true),
      );

      expect(location, '/');
    });

    testWidgets('the marker is consumed by the redirect', (tester) async {
      pseudoCreationMarker.mark();
      await _landing(
        tester,
        PseudoRoute().location,
        session: _session(hasPseudo: true),
      );

      expect(pseudoCreationMarker.consume(), isFalse);
    });

    testWidgets('leads to the birthday step without redirectTo',
        (tester) async {
      pseudoCreationMarker.mark();
      final location = await _landing(
        tester,
        PseudoRoute().location,
        session: _session(hasPseudo: true),
      );

      expect(location, '/birthday');
    });

    testWidgets(
        'a marker left by a session ended during the creation is cleared, '
        'so an old link to /pseudo later goes home', (tester) async {
      pseudoCreationMarker.mark();
      // The session ends while the profile is being created
      await _landing(tester, PseudoRoute().location, session: null);

      final location = await _landing(
        tester,
        PseudoRoute().location,
        session: _session(hasPseudo: true),
      );

      expect(location, '/');
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
