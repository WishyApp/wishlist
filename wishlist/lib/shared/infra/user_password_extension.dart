import 'package:supabase_flutter/supabase_flutter.dart';

extension UserPasswordExtension on User {
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
    final providers = appMetadata['providers'];
    if (providers is! List) {
      return true;
    }
    return providers.contains('email');
  }
}
