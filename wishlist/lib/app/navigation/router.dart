import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wishlist/app/navigation/app_redirect.dart';
import 'package:wishlist/app/navigation/sentry_route_name_extractor.dart';
import 'package:wishlist/main.dart';
import 'package:wishlist/shared/navigation/app_route_observer.dart';
import 'package:wishlist/shared/navigation/routes.dart';

final _authStateNotifier = AuthStateNotifier(supabase.auth.onAuthStateChange);

final router = GoRouter(
  initialLocation: HomeRoute().location,
  refreshListenable: _authStateNotifier,
  routes: $appRoutes,
  observers: [
    appRouteObserver,
    SentryNavigatorObserver(routeNameExtractor: sentryRouteNameExtractor),
  ],
  redirect: (context, state) =>
      appRedirect(state, session: supabase.auth.currentSession),
);
