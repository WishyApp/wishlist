import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wishlist/app/app.dart';
import 'package:wishlist/app/config/config.dart';
import 'package:wishlist/app/config/config_provider.dart';
import 'package:wishlist/app/config/environment.dart';
import 'package:wishlist/app/config/environment_provider.dart';
import 'package:wishlist/app/config/environment_service.dart';
import 'package:wishlist/shared/infra/crash_reporting_preference.dart';
import 'package:wishlist/shared/infra/sentry_user_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = Environment.values.byName(EnvironmentService.appEnv);

  final config = await Config.load(environment: environment);

  final sentryDsn = config.sentryDsn;
  final prefs = await SharedPreferences.getInstance();
  final isSentryEnabled = shouldEnableSentry(
    dsn: sentryDsn,
    userEnabled: CrashReportingPreference(prefs).isEnabled(),
    isRelease: kReleaseMode,
  );

  Future<void> startApp() async {
    await Supabase.initialize(
      url: config.supabaseConfig.url,
      anonKey: config.supabaseConfig.anonKey,
    );

    if (sentryDsn != null && isSentryEnabled) {
      // Lives as long as the app, so it is never disposed.
      SentryUserSync(
        authStateChanges: Supabase.instance.client.auth.onAuthStateChange,
      ).start();
    }

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

  if (sentryDsn != null && isSentryEnabled) {
    await SentryFlutter.init(
      (options) {
        options
          ..dsn = sentryDsn
          ..environment = environment.name
          ..sendDefaultPii = false
          ..tracesSampleRate = 0
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
