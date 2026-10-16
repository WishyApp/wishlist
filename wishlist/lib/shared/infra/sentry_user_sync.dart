import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Sentry user in sync with the Supabase session.
///
/// Only the user id is shared with Sentry (no email, no pseudo).
class SentryUserSync {
  SentryUserSync({
    required Stream<AuthState> authStateChanges,
    FutureOr<void> Function(String? userId)? setUser,
  })  : _authStateChanges = authStateChanges,
        _setUser = setUser ?? _setSentryUser;

  final Stream<AuthState> _authStateChanges;
  final FutureOr<void> Function(String? userId) _setUser;
  StreamSubscription<AuthState>? _subscription;

  static FutureOr<void> _setSentryUser(String? userId) {
    return Sentry.configureScope(
      (scope) => scope.setUser(userId == null ? null : SentryUser(id: userId)),
    );
  }

  void start() {
    _subscription ??= _authStateChanges.listen(
      (state) => _applyUser(state.session?.user.id),
    );
  }

  /// Crash reporting must never break the auth flow, so errors are only logged.
  Future<void> _applyUser(String? userId) async {
    try {
      await _setUser(userId);
    } catch (error) {
      debugPrint('Could not update the Sentry user: $error');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
