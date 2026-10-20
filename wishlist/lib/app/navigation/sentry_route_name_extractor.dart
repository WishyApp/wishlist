import 'package:flutter/widgets.dart';

/// Keeps only the route name for Sentry breadcrumbs, so route arguments (path
/// parameters, `redirectTo` query...) are never sent.
RouteSettings? sentryRouteNameExtractor(RouteSettings? settings) {
  if (settings == null) {
    return null;
  }

  return RouteSettings(name: settings.name);
}
