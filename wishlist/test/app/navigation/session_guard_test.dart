import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/app/navigation/app_redirect.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/auth/view/auth_screen.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/non_null_extensions/go_true_client_non_null_getter_user_extension.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/navigation/authenticated_route.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/theme.dart';
import 'package:wishlist/shared/widgets/dialogs/create_dialog.dart';

import '../../fixtures/fake_data.dart';
import '../../fixtures/fake_providers.dart';
import '../../fixtures/mock_supabase.dart';

const _boundKey = Key('user-bound');

/// A user-bound screen like the ones of the app: it follows the user id (so it
/// rebuilds when the session changes) and reads the user in `build`, which
/// throws a 401 without a session.
class _UserBoundScreen extends ConsumerWidget {
  const _UserBoundScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentUserIdProvider);
    final user = ref.read(supabaseClientProvider).auth.currentUserNonNull;
    return Scaffold(
      key: _boundKey,
      body: Center(
        child: TextButton(
          onPressed: () => showCreateDialog(context, ref),
          child: Text('bound ${user.id}'),
        ),
      ),
    );
  }
}

Widget _app(
  FakeAuthSession session, {
  GoRouter? router,
  Widget? home,
}) {
  return ProviderScope(
    overrides: [
      configOverride(),
      supabaseClientProvider.overrideWithValue(session.client),
    ],
    child: router != null
        ? MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
          )
        : MaterialApp(
            home: home,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
          ),
  );
}

void main() {
  testWidgets(
    'signing out on a user-bound screen lands on the auth screen without '
    'building anything bound to the user (real redirect, synchronous notify)',
    (tester) async {
      final session = FakeAuthSession(userId: fakeCurrentUserId);
      addTearDown(session.close);

      // Same wiring as router.dart: refresh on every auth event, same redirect.
      final refresh = AuthStateNotifier(session.auth.onAuthStateChange);
      addTearDown(refresh.dispose);
      final router = GoRouter(
        initialLocation: '/bound',
        refreshListenable: refresh,
        routes: [
          ...$appRoutes,
          GoRoute(
            path: '/bound',
            builder: (_, __) =>
                const SessionGuard(builder: _UserBoundScreen.new),
          ),
        ],
        redirect: (context, state) =>
            appRedirect(state, session: session.auth.currentSession),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(session, router: router));
      await tester.pumpAndSettle();
      expect(find.byKey(_boundKey), findsOneWidget);

      session.signOut();
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(_boundKey), findsNothing);
      expect(find.byType(AuthScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a rebuild while currentUser is already null, before any auth event, '
    'builds nothing bound to the user',
    (tester) async {
      final session = FakeAuthSession(userId: fakeCurrentUserId);
      addTearDown(session.close);
      final rebuild = ValueNotifier(0);
      addTearDown(rebuild.dispose);

      await tester.pumpWidget(
        _app(
          session,
          home: ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (_, __, ___) =>
                SessionGuard(builder: () => const _UserBoundScreen()),
          ),
        ),
      );
      expect(find.byKey(_boundKey), findsOneWidget);

      // gotrue clears the user, then awaits its storage, then emits
      // signedOut: currentUserIdProvider has not changed yet.
      session.setUserSilently(null);
      rebuild.value++;
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(_boundKey), findsNothing);
    },
  );

  testWidgets(
    'closes a dialog opened by the screen when the session ends',
    (tester) async {
      final session = FakeAuthSession(userId: fakeCurrentUserId);
      addTearDown(session.close);

      await tester.pumpWidget(
        _app(session, home: const SessionGuard(builder: _UserBoundScreen.new)),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      session.signOut();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(_boundKey), findsNothing);
    },
  );

  group('every route but the auth ones is behind the session guard', () {
    // Public routes, the ones appRedirect lets through without a session.
    const publicPaths = {
      '/auth',
      '/auth/forgot-password',
      '/auth/reset-password',
    };

    final cases = <({String path, int depth})>[];
    void walk(List<RouteBase> routes, String parent, int depth) {
      for (final route in routes.whereType<GoRoute>()) {
        final path = route.path.startsWith('/')
            ? route.path
            : parent.endsWith('/')
                ? '$parent${route.path}'
                : '$parent/${route.path}';
        // ':wishlistId' -> '1': ids are ints or free strings.
        final location = path.replaceAll(RegExp(':[A-Za-z]+'), '1');
        cases.add((path: location, depth: depth + 1));
        walk(route.routes, path, depth + 1);
      }
    }

    walk($appRoutes, '', 0);

    test('walks the whole route tree', () {
      expect(cases.map((c) => c.path), containsAll(publicPaths));
      expect(cases.length, greaterThan(publicPaths.length));
    });

    for (final c in cases) {
      testWidgets(c.path, (tester) async {
        // Signed out and no redirect: a guarded page shows nothing of the
        // route, a public page does not use the guard.
        final session = FakeAuthSession();
        addTearDown(session.close);
        final router = GoRouter(
          initialLocation: c.path,
          routes: $appRoutes,
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(_app(session, router: router));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final guards = find.byType(SessionGuard, skipOffstage: false);
        if (publicPaths.contains(c.path)) {
          expect(guards, findsNothing);
        } else {
          // One guarded page per route of the chain, parents included.
          expect(guards, findsNWidgets(c.depth));
        }
      });
    }
  });
}
