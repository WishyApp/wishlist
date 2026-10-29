import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/modules/home/cards/wishlists_last_activity_provider.dart';
import 'package:wishlist/shared/navigation/app_route_observer.dart';

/// Reads the data that does not follow the live streams again when the user
/// comes back to the home: from any screen pushed over it (a wishlist where
/// wishes were added, say) and from the background (the last activity only,
/// a new day is handled by `homeCardsProvider`).
class HomeRefreshOnReturn extends ConsumerStatefulWidget {
  const HomeRefreshOnReturn({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeRefreshOnReturn> createState() =>
      _HomeRefreshOnReturnState();
}

class _HomeRefreshOnReturnState extends ConsumerState<HomeRefreshOnReturn>
    with RouteAware {
  late final AppLifecycleListener _lifecycleListener;
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      // A new day is handled by the cards themselves (`homeCardsProvider`
      // recomputes on resume when the day changed): only the last activity,
      // which no live stream follows, is read again. The cards reload with
      // it when they depend on it.
      onResume: () => ref.invalidate(wishlistsLastActivityProvider),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) {
        appRouteObserver.subscribe(this, route);
      }
    }
  }

  @override
  void didPopNext() {
    // The screen pushed over the home may have changed what no live stream
    // follows (wishes of a list, card states): both are read again.
    ref
      ..invalidate(wishlistsLastActivityProvider)
      ..invalidate(homeCardsProvider);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
