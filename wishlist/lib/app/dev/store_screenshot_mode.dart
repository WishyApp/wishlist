import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/navigation/router.dart';

/// Debug-only helper used by `scripts/store-screenshots` to capture the store
/// visuals: signs in with a demo account and navigates to the routes written
/// in a file (the iOS simulator shows a confirmation dialog for every
/// custom-scheme link, so deep links are not usable).
///
/// Enabled with `--dart-define=SHOTS_EMAIL=... SHOTS_PASSWORD=...
/// SHOTS_ROUTE_FILE=...`. Compiled out of release builds (`kDebugMode`).
abstract final class StoreScreenshotMode {
  static const _email = String.fromEnvironment('SHOTS_EMAIL');
  static const _password = String.fromEnvironment('SHOTS_PASSWORD');
  static const _routeFile = String.fromEnvironment('SHOTS_ROUTE_FILE');

  static const bool enabled = kDebugMode && _email != '';

  static Future<void> setUp() async {
    if (!enabled) {
      return;
    }

    await Supabase.instance.client.auth.signInWithPassword(
      email: _email,
      password: _password,
    );

    if (_routeFile.isEmpty) {
      return;
    }
    final file = File(_routeFile);
    var lastRoute = '';
    Timer.periodic(const Duration(milliseconds: 500), (_) {
      try {
        final route = file.readAsStringSync().trim();
        if (route.isNotEmpty && route != lastRoute) {
          lastRoute = route;
          router.go(route);
        }
      } on FileSystemException {
        // The route file does not exist yet.
      }
    });
  }
}
