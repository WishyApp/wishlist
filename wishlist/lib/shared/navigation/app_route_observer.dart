import 'package:flutter/widgets.dart';

/// Lets a screen know when it becomes the current route again (`RouteAware`),
/// whatever screen was pushed over it. Registered on the router.
final appRouteObserver = RouteObserver<ModalRoute<void>>();
