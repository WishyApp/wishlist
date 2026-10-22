import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wishlist/app/dev/store_screenshot_mode.dart';
import 'package:wishlist/app/navigation/router.dart';
import 'package:wishlist/app/version_gate/app_version_gate.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/share_intent_handler.dart';
import 'package:wishlist/shared/theme/theme.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // ignore: avoid_redundant_argument_values
      debugShowCheckedModeBanner: !StoreScreenshotMode.enabled,
      restorationScopeId: 'app',
      onGenerateTitle: (context) => 'Wishy',
      builder: (context, child) => ShareIntentHandler(
        child: AppVersionGate(
          navigatorKey: router.routerDelegate.navigatorKey,
          child: child ??
              const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
      routerConfig: router,
      theme: theme,
    );
  }
}
