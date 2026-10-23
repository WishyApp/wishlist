import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

/// Base of every route that needs a session (all but auth, forgot password and
/// reset password, which the router redirect lets through without one).
///
/// On sign-out the session is cleared before go_router's redirect lands, so
/// the current screen can rebuild once without a user. Anything it reads
/// through `currentUserNonNull` there would throw a 401. [SessionGuard] builds
/// nothing of the route in that case: [buildScreen] is not even called.
///
/// Subclasses implement [buildScreen] instead of `build`.
abstract class AuthenticatedRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      SessionGuard(builder: () => buildScreen(context, state));

  Widget buildScreen(BuildContext context, GoRouterState state);
}

/// Shows what [builder] returns only while there is a session, an empty page
/// otherwise.
///
/// Two conditions must hold, because they do not flip at the same time on
/// sign-out (gotrue clears `currentUser`, then awaits its storage, then emits
/// `signedOut`):
/// - `currentUserIdProvider` is not null: the guard rebuilds when it changes;
/// - `auth.currentUser` is not null, read live at build time: covers a rebuild
///   of the guard in the window where the provider has not caught up yet.
///
/// When the session goes away, popups of the root navigator (dialogs, bottom
/// sheets) are closed once: they were opened by the screen being removed and
/// hold its `ref`. Pages are not popups, so this does not interfere with the
/// router's redirect.
class SessionGuard extends ConsumerStatefulWidget {
  const SessionGuard({required this.builder, super.key});

  final Widget Function() builder;

  @override
  ConsumerState<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends ConsumerState<SessionGuard> {
  bool _popupsClosed = false;

  @override
  Widget build(BuildContext context) {
    final hasUserId = ref.watch(currentUserIdProvider) != null;
    final hasLiveUser =
        ref.read(supabaseClientProvider).auth.currentUser != null;

    if (hasUserId && hasLiveUser) {
      _popupsClosed = false;
      return widget.builder();
    }

    if (!_popupsClosed) {
      _popupsClosed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route is! PopupRoute);
      });
    }
    return const Scaffold();
  }
}
