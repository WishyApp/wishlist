import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';

/// Base of every route that needs a session (all but auth, forgot password and
/// reset password, which the router redirect lets through without one).
///
/// On sign-out the session is cleared before go_router's redirect lands, so
/// the current screen can rebuild once without a user. Anything it reads
/// through `currentUserNonNull` there would throw a 401. [SessionGuard] builds
/// nothing of the screen in that frame, whatever the screen does.
///
/// Subclasses implement [buildScreen] instead of `build`.
abstract class AuthenticatedRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      SessionGuard(child: buildScreen(context, state));

  Widget buildScreen(BuildContext context, GoRouterState state);
}

/// Shows [child] only while there is a session, an empty page otherwise.
class SessionGuard extends ConsumerWidget {
  const SessionGuard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserIdProvider) == null) {
      return const Scaffold();
    }
    return child;
  }
}
