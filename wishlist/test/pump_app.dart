import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/theme.dart';

extension EnhancedWidgetTester on WidgetTester {
  Widget _addReusableWrapper(
    Widget child, {
    required WindowConfigData? windowConfig,
  }) {
    var app = child;

    if (windowConfig != null) {
      app = AdaptiveWrapper(
        windowConfig: windowConfig,
        tester: this,
        child: app,
      );
    }

    return app;
  }

  List<LocalizationsDelegate<Object?>> get _localizationsDelegates => [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  Locale get _defaultTestLocale => const Locale('fr', 'FR');

  Future<void> pumpApp(
    Widget widget, {
    WindowConfigData? windowConfig,
    List<Override>? overrides,
  }) async {
    final app = ProviderScope(
      overrides: [...overrides ?? []],
      child: _addReusableWrapper(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: _defaultTestLocale,
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          builder: (context, child) {
            return Scaffold(
              body: Material(
                color: Colors.transparent,
                child: child,
              ),
            );
          },
          home: widget,
        ),
        windowConfig: windowConfig,
      ),
    );

    return pumpWidget(app);
  }

  /// Pumps [screen] pushed on top of another route, like in the app: it gets a
  /// back button, unlike a screen pumped as the home route.
  ///
  /// Ends with `pumpAndSettle`, which never returns while a spinner is shown:
  /// pass `settle: false` to only pump the route transition for such screens.
  Future<void> pumpPushedScreen(
    Widget screen, {
    List<Override>? overrides,
    bool settle = true,
  }) async {
    await pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => screen),
          ),
          child: const Text('open'),
        ),
      ),
      overrides: overrides,
    );
    await tap(find.text('open'));
    if (settle) {
      await pumpAndSettle();
    } else {
      // Route transition: the first frame only starts its animation
      await pump();
      await pump(const Duration(seconds: 1));
    }
  }

  Future<void> pumpRouterApp(
    String path, {
    WindowConfigData? windowConfig,
    List<Override>? overrides,
    Object? initialExtra,
    List<RouteBase>? routes,
    GlobalKey<NavigatorState>? navigatorKey,
    TransitionBuilder? builder,
  }) async {
    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialExtra: initialExtra,
      initialLocation: path,
      routes: routes ?? $appRoutes,
    );

    final app = ProviderScope(
      overrides: [...overrides ?? []],
      child: _addReusableWrapper(
        MaterialApp.router(
          routerConfig: router,
          builder: builder,
          locale: _defaultTestLocale,
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: theme,
        ),
        windowConfig: windowConfig,
      ),
    );

    return pumpWidget(app);
  }
}
