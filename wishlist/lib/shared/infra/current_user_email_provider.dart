import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/repositories/user/user_repository_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

/// Email of the current user, kept in sync with the auth state.
///
/// Null means "nobody is signed in (e.g. right after a sign-out, before the
/// redirect) OR the account has no email": callers must not treat null as
/// "signed out", use `currentUserIdProvider` for that.
///
/// Same pattern as `currentUserIdProvider`: a synchronous value read from
/// `auth.currentUser` (not from the event session, `currentUser` can already
/// be null before `signedOut` is emitted), resynced on every auth event.
/// Equal values are not notified, so token refreshes and replays are free.
final currentUserEmailProvider =
    NotifierProvider<CurrentUserEmailNotifier, String?>(
  CurrentUserEmailNotifier.new,
);

class CurrentUserEmailNotifier extends Notifier<String?> {
  @override
  String? build() {
    final auth = ref.watch(supabaseClientProvider).auth;
    final repository = ref.watch(userRepositoryProvider);

    void sync() {
      final email = repository.getCurrentUserEmail();
      if (email != state) {
        state = email;
      }
    }

    // gotrue also pushes exceptions into this stream (notifyException): resync
    // from currentUser and swallow them, they are not ours to handle.
    final subscription = auth.onAuthStateChange.listen(
      (_) => sync(),
      onError: (_) => sync(),
    );
    ref.onDispose(subscription.cancel);

    return repository.getCurrentUserEmail();
  }
}
