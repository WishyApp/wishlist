import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_auth_providers_extension.dart';

/// Whether the current user can change a password, kept in sync with the
/// auth state: false for an account created with Google or Apple only.
///
/// True when nobody is signed in, so that a screen rebuilt right after a
/// sign-out keeps its layout. Same pattern as `currentUserEmailProvider`.
final currentUserHasPasswordProvider =
    NotifierProvider<CurrentUserHasPasswordNotifier, bool>(
  CurrentUserHasPasswordNotifier.new,
);

class CurrentUserHasPasswordNotifier extends Notifier<bool> {
  @override
  bool build() {
    final auth = ref.watch(supabaseClientProvider).auth;

    bool read() => auth.currentUser?.hasPassword ?? true;

    void sync() {
      final hasPassword = read();
      if (hasPassword != state) {
        state = hasPassword;
      }
    }

    // gotrue also pushes exceptions into this stream (notifyException): resync
    // from currentUser and swallow them, they are not ours to handle.
    final subscription = auth.onAuthStateChange.listen(
      (_) => sync(),
      onError: (_) => sync(),
    );
    ref.onDispose(subscription.cancel);

    return read();
  }
}
