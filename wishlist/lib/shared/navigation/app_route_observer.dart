import 'package:flutter/widgets.dart';

/// Lets a screen know when it becomes the current route again (`RouteAware`),
/// whatever screen was pushed over it. Registered on the router. Page routes
/// only: closing a dialog or a bottom sheet over a screen is not a return.
final appRouteObserver = RouteObserver<PageRoute<void>>();
