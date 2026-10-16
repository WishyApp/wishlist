import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

/// Id of the signed-in user, or null without a session.
///
/// Every provider that holds or derives data bound to the current user must
/// `ref.watch` it, so that a logout or a user switch rebuilds it instead of
/// leaving the previous user's data (or stream) alive (F015).
///
/// It is a synchronous value rather than a StreamProvider: the initial value
/// comes from `auth.currentUser`, so dependents never go through a loading
/// state on the first frame, and there is no AsyncValue to unwrap.
///
/// The id is always read from `auth.currentUser`, not from the event session:
/// gotrue's `onAuthStateChange` replays its last event to new subscribers,
/// and `currentUser` can already be null before `signedOut` is emitted.
/// Equal ids are not notified, so token refreshes and replays are free.
final currentUserIdProvider = NotifierProvider<CurrentUserIdNotifier, String?>(
  CurrentUserIdNotifier.new,
);

class CurrentUserIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final auth = ref.watch(supabaseClientProvider).auth;

    final subscription = auth.onAuthStateChange.listen((_) {
      final id = auth.currentUser?.id;
      if (id != state) {
        state = id;
      }
    });
    ref.onDispose(subscription.cancel);

    return auth.currentUser?.id;
  }
}
