import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/auth/view/auth_screen.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/shared/infra/repositories/user/user_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/user/user_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/theme.dart';

import '../../fixtures/fake_data.dart';
import '../../fixtures/fake_providers.dart';
import '../../fixtures/mock_supabase.dart';

/// Notifies the router only once the frame that follows the auth event is
/// built, like in the app where the screen rebuilds before the redirect lands.
class _MockUserStreamRepository extends Mock implements UserStreamRepository {}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(FakeAuthSession session) {
    session.auth.onAuthStateChange.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    });
  }
}

void main() {
  testWidgets(
    'signing out on a user-bound screen builds nothing bound to the user '
    'before the redirect lands on the auth screen',
    (tester) async {
      final session = FakeAuthSession(userId: fakeCurrentUserId);
      addTearDown(session.close);

      final user = session.auth.currentUser!;
      when(() => user.email).thenReturn('test@example.com');

      // The real watchCurrentUserProfileProvider follows the user id, so the
      // settings rebuild in the sign-out frame.
      final userStreams = _MockUserStreamRepository();
      when(() => userStreams.watchProfileById(any()))
          .thenAnswer((_) => Stream.value(fakeCurrentUserProfile));

      final router = GoRouter(
        initialLocation: SettingsRoute().location,
        routes: $appRoutes,
        refreshListenable: _AuthRefresh(session),
        // Same contract as app/navigation/router.dart for a signed-out user.
        redirect: (context, state) {
          final isAuthRoute = state.matchedLocation.startsWith('/auth');
          if (session.auth.currentUser == null && !isAuthRoute) {
            return AuthRoute().location;
          }
          return null;
        },
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(session.client),
            userStreamRepositoryProvider.overrideWithValue(userStreams),
            appInfoOverride(),
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
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);

      // currentUser is cleared and the providers rebuild, but the router has
      // not redirected yet: the first frame must not rebuild the settings.
      session.signOut();
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(AuthScreen), findsOneWidget);
    },
  );
}
