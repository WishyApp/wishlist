import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/modules/home/cards/wishlists_last_activity_provider.dart';
import 'package:wishlist/shared/navigation/app_route_observer.dart';

/// Reads the data that does not follow the live streams again when the user
/// comes back to the home: from any screen pushed over it (a wishlist where
/// wishes were added, say) and from the background (a new day may have come).
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
      onResume: () {
        // The cards are computed against the clock: they are built again too
        ref
          ..invalidate(wishlistsLastActivityProvider)
          ..invalidate(homeCardsProvider);
      },
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
    // The cards reload with it, when they depend on it
    ref.invalidate(wishlistsLastActivityProvider);
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
