import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/navigation/pseudo_creation_marker.dart';
import 'package:wishlist/shared/navigation/redirect_target.dart';
import 'package:wishlist/shared/navigation/routes.dart';

/// Tells go_router to re-run its redirect on every auth event.
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(Stream<AuthState> authStateChanges) {
    // gotrue also pushes refresh failures into this stream (e.g. when resuming
    // offline). They are not ours to handle: without onError they would reach
    // the zone handler and Sentry.
    _subscription = authStateChanges.listen(
      (_) => notifyListeners(),
      onError: (Object error) => debugPrint(
        'Ignored auth stream error in the router: $error',
      ),
    );
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

bool _isOnRoute(GoRouterState state, String routeLocation) {
  return routeLocation.split('/').last == state.matchedLocation.split('/').last;
}

/// The router's redirect, taking the live [session] (null when signed out).
///
/// Auth, forgot password and reset password are the only routes reachable
/// without a session: keep them in sync with the `AuthenticatedRoute` base
/// class of `shared/navigation/routes.dart`.
///
/// [creationMarker] is read to tell a pseudo just created from an existing one.
String? appRedirect(
  GoRouterState state, {
  required Session? session,
  PseudoCreationMarker? creationMarker,
}) {
  final redirectTo = sanitizeRedirectTarget(
    state.uri.queryParameters['redirectTo'],
  );
  final currentLocation = state.uri.toString();
  final currentTarget = sanitizeRedirectTarget(currentLocation);

  final isOnAuthScreen = _isOnRoute(state, AuthRoute().location);
  final isOnPseudoScreen = _isOnRoute(state, PseudoRoute().location);
  final isOnForgotPasswordScreen =
      _isOnRoute(state, ForgotPasswordRoute().location);
  final isOnResetPasswordScreen =
      _isOnRoute(state, ResetPasswordRoute().location);

  // Allow access to password recovery screens without authentication
  if (isOnForgotPasswordScreen || isOnResetPasswordScreen) {
    return null;
  }

  if (session == null) {
    if (isOnAuthScreen) {
      return null;
    }

    if (currentTarget == null) {
      return AuthRoute().location;
    }

    return locationWithRedirectTo(
      AuthRoute().location,
      currentTarget,
    );
  }

  final hasPseudo = session.user.userMetadata?.containsKey('pseudo');
  if (hasPseudo == null || !hasPseudo) {
    if (isOnPseudoScreen) {
      return null;
    }

    if (redirectTo != null) {
      return locationWithRedirectTo(
        PseudoRoute().location,
        redirectTo,
      );
    }

    return PseudoRoute().location;
  }

  // Creating the pseudo refreshes the session, which runs this redirect before
  // the pseudo screen gets to navigate: send the new user to the optional
  // birthday step, which then goes to [redirectTo] or home itself. Only a
  // pseudo just created leads there (an existing user opening /pseudo from an
  // old link goes on as before), and nothing forces the step: it never
  // redirects based on the birthday.
  if (isOnPseudoScreen) {
    if ((creationMarker ?? pseudoCreationMarker).consume()) {
      return locationWithRedirectTo(BirthdayStepRoute().location, redirectTo);
    }

    return redirectTo ?? HomeRoute().location;
  }

  if (isOnAuthScreen) {
    return redirectTo ?? HomeRoute().location;
  }

  return null;
}
