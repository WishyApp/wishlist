import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/config/deeplink_config.dart';
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

String? _sanitizeRedirectTarget(String? target) {
  if (target == null || target.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(target);
  if (uri == null) {
    return null;
  }

  if (!uri.hasScheme && !uri.hasAuthority) {
    if (!target.startsWith('/')) {
      return null;
    }

    return target;
  }

  final isWishyDeepLink = DeeplinkConfig.isValidDeeplink(uri);

  if (!isWishyDeepLink || !uri.path.startsWith('/')) {
    return null;
  }

  return Uri(
    path: uri.path,
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  ).toString();
}

String _buildLocationWithRedirectTo(
  String baseLocation,
  String redirectTo,
) {
  return Uri(
    path: baseLocation,
    queryParameters: {
      'redirectTo': redirectTo,
    },
  ).toString();
}

/// The router's redirect, taking the live [session] (null when signed out).
///
/// Auth, forgot password and reset password are the only routes reachable
/// without a session: keep them in sync with the `AuthenticatedRoute` base
/// class of `shared/navigation/routes.dart`.
String? appRedirect(GoRouterState state, {required Session? session}) {
  final redirectTo = _sanitizeRedirectTarget(
    state.uri.queryParameters['redirectTo'],
  );
  final currentLocation = state.uri.toString();
  final currentTarget = _sanitizeRedirectTarget(currentLocation);

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

    return _buildLocationWithRedirectTo(
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
      return _buildLocationWithRedirectTo(
        PseudoRoute().location,
        redirectTo,
      );
    }

    return PseudoRoute().location;
  }

  if (isOnAuthScreen || isOnPseudoScreen) {
    return redirectTo ?? HomeRoute().location;
  }

  return null;
}
