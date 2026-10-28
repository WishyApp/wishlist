import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the sign-in methods Supabase lists in `app_metadata.providers`.
extension UserAuthProvidersExtension on User {
  List<Object?>? get _providers {
    final providers = appMetadata['providers'];
    return providers is List ? providers : null;
  }

  /// False for an account created with Google or Apple only: it has no
  /// password to change.
  ///
  /// Supabase lists the sign-in methods in `app_metadata.providers`, "email"
  /// standing for email + password. An older session without the list is
  /// treated as having a password, as all accounts did before.
  ///
  /// A Google or Apple account that sets a password through "forgot password"
  /// keeps its providers list: it can still change it the same way.
  bool get hasPassword {
    final providers = _providers;
    if (providers == null) {
      return true;
    }
    return providers.contains('email');
  }

  /// True when the account can sign in with Apple: its Apple tokens must be
  /// revoked when it is deleted.
  bool get hasAppleSignIn => _providers?.contains('apple') ?? false;
}
