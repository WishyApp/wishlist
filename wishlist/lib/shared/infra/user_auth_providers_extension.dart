import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the sign-in methods Supabase lists in `app_metadata.providers`,
/// "email" standing for email + password.
extension UserAuthProvidersExtension on User {
  List<Object?>? get _providers {
    final providers = appMetadata['providers'];
    return providers is List ? providers : null;
  }

  /// False for an account created with Google or Apple only: it has no
  /// password to change.
  ///
  /// An older session without the list is treated as having a password, as
  /// all accounts did before. A Google or Apple account that sets a password
  /// through "forgot password" keeps its providers list: it can still change
  /// it the same way.
  bool get hasPassword => _providers?.contains('email') ?? true;

  /// True when the account can sign in with Google.
  bool get hasGoogleSignIn => _providers?.contains('google') ?? false;
}
