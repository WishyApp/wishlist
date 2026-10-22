import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wishlist/app/app.dart';
import 'package:wishlist/app/config/config.dart';
import 'package:wishlist/app/config/config_provider.dart';
import 'package:wishlist/app/config/environment.dart';
import 'package:wishlist/app/config/environment_provider.dart';
import 'package:wishlist/app/config/environment_service.dart';
import 'package:wishlist/app/dev/store_screenshot_mode.dart';
import 'package:wishlist/app/navigation/router.dart';
import 'package:wishlist/shared/infra/deep_link_navigator.dart';
import 'package:wishlist/shared/infra/sentry_user_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = Environment.values.byName(EnvironmentService.appEnv);

  final config = await Config.load(environment: environment);

  final sentryDsn = config.sentryDsn;
  // Local debug runs never report, even with the dev DSN.
  final isSentryEnabled = sentryDsn != null && kReleaseMode;

  Future<void> startApp() async {
    await Supabase.initialize(
      url: config.supabaseConfig.url,
      anonKey: config.supabaseConfig.anonKey,
    );

    if (isSentryEnabled) {
      // Lives as long as the app, so it is never disposed.
      SentryUserSync(
        authStateChanges: Supabase.instance.client.auth.onAuthStateChange,
      ).start();
    }

    await StoreScreenshotMode.setUp();

    // Lives as long as the app, so it is never disposed.
    final appLinks = AppLinks();
    unawaited(
      DeepLinkNavigator(
        getInitialLink: appLinks.getInitialLink,
        links: appLinks.uriLinkStream,
        navigate: router.go,
      ).start(),
    );

    runApp(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(config),
          environmentProvider.overrideWithValue(environment),
        ],
        child: const MyApp(),
      ),
    );
  }

  if (isSentryEnabled) {
    await SentryFlutter.init(
      (options) {
        options
          ..dsn = sentryDsn
          ..environment = environment.name
          ..sendDefaultPii = false
          ..attachScreenshot = false;
      },
      appRunner: startApp,
    );
  } else {
    await startApp();
  }
}

// ignore: unreachable_from_main
final supabase = Supabase.instance.client;
