import 'dart:async';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wishlist/app/version_gate/app_update_required_screen.dart';
import 'package:wishlist/app/version_gate/app_version_gate.dart';
import 'package:wishlist/shared/infra/app_info_provider.dart';
import 'package:wishlist/shared/infra/app_update_service.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository_provider.dart';
import 'package:wishlist/shared/models/app_version_policy.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../fixtures/fake_providers.dart';
import '../../pump_app.dart';

class _FakeRepository implements AppVersionRepository {
  _FakeRepository({this.policy, this.error});

  AppVersionPolicy? policy;
  Exception? error;

  /// Next call never completes (hung request).
  bool hangNext = false;
  int calls = 0;

  @override
  Future<AppVersionPolicy?> getPolicy(String platform) async {
    calls++;
    if (hangNext) {
      hangNext = false;
      return Completer<AppVersionPolicy?>().future;
    }
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return policy;
  }
}

const _homeKey = Key('home');

/// Fake clock of the notifier, which throttles the checks on resume.
var _fakeNow = DateTime(2026, 10, 22, 12);

/// The app comes back to the foreground [after] later (past the throttle by
/// default).
void _resume(
  WidgetTester tester, {
  Duration after = const Duration(minutes: 6),
}) {
  _fakeNow = _fakeNow.add(after);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

List<Override> _overrides(
  _FakeRepository repository, {
  String appVersion = '0.2.0',
  String? platform = 'ios',
  List<String>? openedUrls,
}) {
  return [
    appVersionRepositoryProvider.overrideWithValue(repository),
    appUpdatePlatformProvider.overrideWithValue(platform),
    clockProvider.overrideWithValue(() => _fakeNow),
    appInfoProvider.overrideWith(
      (ref) async => PackageInfo(
        appName: 'Wishy',
        packageName: 'com.example.wishlist',
        version: appVersion,
        buildNumber: '1',
      ),
    ),
    if (openedUrls != null)
      appUpdateUrlLauncherProvider.overrideWithValue(
        (url) async => openedUrls.add(url),
      ),
  ];
}

/// The gate in a real GoRouter app, in the same spot as in app.dart (builder
/// of MaterialApp.router, above the Navigator that shows the dialog).
Future<GlobalKey<NavigatorState>> _pumpGate(
  WidgetTester tester,
  List<Override> overrides, {
  Widget home = const Scaffold(key: _homeKey),
  WindowConfigData? windowConfig,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpRouterApp(
    '/',
    overrides: overrides,
    windowConfig: windowConfig,
    navigatorKey: navigatorKey,
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(path: '/detail', builder: (_, __) => const Scaffold()),
    ],
    builder: (context, child) =>
        AppVersionGate(navigatorKey: navigatorKey, child: child!),
  );
  // Post-frame check, then the repository future
  await tester.pump();
  await tester.pump();
  return navigatorKey;
}

void main() {
  setUp(() => _fakeNow = DateTime(2026, 10, 22, 12));

  const required = AppVersionPolicy(
    minVersion: '0.3.0',
    recommendedVersion: '0.3.0',
    updateUrl: 'https://example.com/store',
  );
  const recommended = AppVersionPolicy(
    minVersion: '0.1.0',
    recommendedVersion: '0.3.0',
    updateUrl: 'https://example.com/store',
  );

  group('blocking screen', () {
    testWidgets('replaces the app when the version is below the minimum',
        (tester) async {
      await _pumpGate(tester, _overrides(_FakeRepository(policy: required)));

      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);
      expect(find.text('Mise à jour requise'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.byKey(_homeKey), findsNothing);
    });

    testWidgets('the button opens the update url', (tester) async {
      final opened = <String>[];
      await _pumpGate(
        tester,
        _overrides(_FakeRepository(policy: required), openedUrls: opened),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(opened, ['https://example.com/store']);
    });

    testWidgets('without url: explains the stores and has no button',
        (tester) async {
      await _pumpGate(
        tester,
        _overrides(
          _FakeRepository(
            policy: const AppVersionPolicy(
              minVersion: '0.3.0',
              recommendedVersion: '0.3.0',
            ),
          ),
        ),
      );

      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);
      expect(find.textContaining('TestFlight'), findsOneWidget);
      expect(find.textContaining('Play Store'), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('without url on Android: names the Play Store', (tester) async {
      await _pumpGate(
        tester,
        _overrides(
          _FakeRepository(
            policy: const AppVersionPolicy(
              minVersion: '0.3.0',
              recommendedVersion: '0.3.0',
            ),
          ),
          platform: 'android',
        ),
      );

      expect(find.textContaining('Play Store'), findsOneWidget);
      expect(find.textContaining('TestFlight'), findsNothing);
    });

    testWidgets('has no app bar and no back button', (tester) async {
      await _pumpGate(tester, _overrides(_FakeRepository(policy: required)));

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets(
        'system back is not handled by the app: it exits, like from a root '
        'screen', (tester) async {
      final exits = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') {
            exits.add(call);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pumpGate(tester, _overrides(_FakeRepository(policy: required)));
      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pump();

      expect(handled, isFalse);
      expect(exits, hasLength(1));
    });

    testWidgets('a re-check on resume keeps the wall', (tester) async {
      final repository = _FakeRepository(policy: required);
      await _pumpGate(tester, _overrides(repository));
      expect(repository.calls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      _resume(tester);
      await tester.pump();
      await tester.pump();

      expect(repository.calls, 2);
      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);
    });

    testWidgets(
        'a resume less than 5 minutes after a successful check skips it',
        (tester) async {
      final repository = _FakeRepository(policy: required);
      await _pumpGate(tester, _overrides(repository));

      _resume(tester, after: const Duration(minutes: 4));
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 1);

      _resume(tester, after: const Duration(minutes: 2));
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 2);
    });

    testWidgets('a failed check does not start the throttle', (tester) async {
      final repository = _FakeRepository(error: Exception('offline'));
      await _pumpGate(tester, _overrides(repository));

      _resume(tester, after: Duration.zero);
      await tester.pump();
      await tester.pump();

      expect(repository.calls, 2);
    });

    testWidgets('a hung check times out, lets through, and a later one runs',
        (tester) async {
      final repository = _FakeRepository(policy: required)..hangNext = true;
      await _pumpGate(tester, _overrides(repository));

      expect(repository.calls, 1);
      expect(find.byKey(_homeKey), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      _resume(tester);
      await tester.pump();
      await tester.pump();

      expect(repository.calls, 2);
      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);
    });

    testWidgets('a failed re-check does not unblock', (tester) async {
      final repository = _FakeRepository(policy: required);
      await _pumpGate(tester, _overrides(repository));

      repository.error = Exception('offline');
      _resume(tester);
      await tester.pump();
      await tester.pump();

      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);
    });

    testWidgets('the app is back once the server lowers the minimum',
        (tester) async {
      final repository = _FakeRepository(policy: required);
      await _pumpGate(tester, _overrides(repository));

      repository.policy = const AppVersionPolicy(
        minVersion: '0.0.0',
        recommendedVersion: '0.0.0',
      );
      _resume(tester);
      await tester.pump();
      await tester.pump();

      expect(find.byType(AppUpdateRequiredScreen), findsNothing);
      expect(find.byKey(_homeKey), findsOneWidget);
    });
  });

  group('recommendation dialog', () {
    const title = 'Nouvelle version disponible';

    Future<void> pumpRecommended(
      WidgetTester tester,
      _FakeRepository repository, {
      List<String>? openedUrls,
      String? platform = 'ios',
    }) async {
      await _pumpGate(
        tester,
        _overrides(repository, openedUrls: openedUrls, platform: platform),
      );
      await tester.pumpAndSettle();
    }

    Future<void> resume(WidgetTester tester) async {
      _resume(tester);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('is shown over the usable app', (tester) async {
      await pumpRecommended(tester, _FakeRepository(policy: recommended));

      expect(find.text(title), findsOneWidget);
      expect(find.byType(AppUpdateRequiredScreen), findsNothing);
      expect(find.byKey(_homeKey, skipOffstage: false), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.byType(SecondaryButton), findsOneWidget);
      expect(find.text('Mettre à jour'), findsWidgets);
      expect(find.text('Plus tard'), findsWidgets);
    });

    testWidgets('"Plus tard" closes it', (tester) async {
      await pumpRecommended(tester, _FakeRepository(policy: recommended));

      await tester.tap(find.byType(SecondaryButton));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(find.byKey(_homeKey), findsOneWidget);
    });

    testWidgets('is shown only once per session', (tester) async {
      final repository = _FakeRepository(policy: recommended);
      await pumpRecommended(tester, repository);
      await tester.tap(find.byType(SecondaryButton));
      await tester.pumpAndSettle();

      await resume(tester);

      expect(repository.calls, 2);
      expect(find.text(title), findsNothing);
    });

    testWidgets('is not stacked again while it is still open', (tester) async {
      final repository = _FakeRepository(policy: recommended);
      await pumpRecommended(tester, repository);

      await resume(tester);

      expect(repository.calls, 2);
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('"Mettre à jour" opens the url and closes it', (tester) async {
      final opened = <String>[];
      await pumpRecommended(
        tester,
        _FakeRepository(policy: recommended),
        openedUrls: opened,
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(opened, ['https://example.com/store']);
      expect(find.text(title), findsNothing);
    });

    testWidgets('without url: no confirm button, names TestFlight on iOS',
        (tester) async {
      await pumpRecommended(
        tester,
        _FakeRepository(
          policy: const AppVersionPolicy(
            minVersion: '0.1.0',
            recommendedVersion: '0.3.0',
          ),
        ),
      );

      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.byType(SecondaryButton), findsOneWidget);
      expect(find.textContaining('TestFlight'), findsOneWidget);
    });

    testWidgets('without url on Android: names the Play Store', (tester) async {
      await pumpRecommended(
        tester,
        _FakeRepository(
          policy: const AppVersionPolicy(
            minVersion: '0.1.0',
            recommendedVersion: '0.3.0',
          ),
        ),
        platform: 'android',
      );

      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.textContaining('Play Store'), findsOneWidget);
      expect(find.textContaining('TestFlight'), findsNothing);
    });

    testWidgets('is closed when the app is up to date again', (tester) async {
      final repository = _FakeRepository(policy: recommended);
      await pumpRecommended(tester, repository);
      expect(find.text(title), findsOneWidget);

      repository.policy = const AppVersionPolicy(
        minVersion: '0.0.0',
        recommendedVersion: '0.0.0',
      );
      await resume(tester);

      expect(find.text(title), findsNothing);
      expect(find.byKey(_homeKey), findsOneWidget);
    });

    testWidgets('closing it leaves a page opened above it alone',
        (tester) async {
      final repository = _FakeRepository(policy: recommended);
      final navigatorKey = await _pumpGate(tester, _overrides(repository));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);

      // A share or a deep link opens a page over the dialog
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(key: Key('page')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      repository.policy = const AppVersionPolicy(
        minVersion: '0.0.0',
        recommendedVersion: '0.0.0',
      );
      _resume(tester);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page')), findsOneWidget);
      expect(find.text(title, skipOffstage: false), findsNothing);
    });

    testWidgets('a dialog already removed is not closed again', (tester) async {
      final repository = _FakeRepository(policy: recommended);
      final navigatorKey = await _pumpGate(tester, _overrides(repository));
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.text(title)))!;

      // Removed without going through the buttons, then a page opens
      navigatorKey.currentState!.removeRoute(route);
      await tester.pumpAndSettle();
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(key: Key('page')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      repository.policy = const AppVersionPolicy(
        minVersion: '0.0.0',
        recommendedVersion: '0.0.0',
      );
      _resume(tester);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page')), findsOneWidget);
    });

    testWidgets('gives way to the wall when the minimum is raised',
        (tester) async {
      final repository = _FakeRepository(policy: recommended);
      await pumpRecommended(tester, repository);
      expect(find.text(title), findsOneWidget);

      repository.policy = required;
      await resume(tester);

      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);
      expect(find.text(title), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is never shown over the wall', (tester) async {
      await pumpRecommended(tester, _FakeRepository(policy: required));

      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);
      expect(find.text(title), findsNothing);
    });
  });

  group('lets the user through', () {
    Future<void> expectNothingShown(WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byKey(_homeKey), findsOneWidget);
      expect(find.byType(AppUpdateRequiredScreen), findsNothing);
      expect(find.text('Nouvelle version disponible'), findsNothing);
      expect(tester.takeException(), isNull);
    }

    testWidgets('when the check throws', (tester) async {
      await _pumpGate(
        tester,
        _overrides(_FakeRepository(error: Exception('offline'))),
      );
      await expectNothingShown(tester);
    });

    testWidgets('when there is no row', (tester) async {
      await _pumpGate(tester, _overrides(_FakeRepository()));
      await expectNothingShown(tester);
    });

    testWidgets('when the policy is unparsable', (tester) async {
      await _pumpGate(
        tester,
        _overrides(
          _FakeRepository(
            policy: const AppVersionPolicy(
              minVersion: 'abc',
              recommendedVersion: '',
            ),
          ),
        ),
      );
      await expectNothingShown(tester);
    });

    testWidgets('when the app version is unparsable', (tester) async {
      await _pumpGate(
        tester,
        _overrides(_FakeRepository(policy: required), appVersion: 'dev'),
      );
      await expectNothingShown(tester);
    });

    testWidgets('when the app is up to date', (tester) async {
      await _pumpGate(
        tester,
        _overrides(_FakeRepository(policy: required), appVersion: '0.3.0'),
      );
      await expectNothingShown(tester);
    });

    testWidgets('on a platform without policy, without asking the server',
        (tester) async {
      final repository = _FakeRepository(policy: required);
      await _pumpGate(tester, _overrides(repository, platform: null));

      expect(repository.calls, 0);
      await expectNothingShown(tester);
    });

    testWidgets('while the check is still running', (tester) async {
      final completer = Completer<AppVersionPolicy?>();
      await _pumpGate(
        tester,
        [
          ..._overrides(_FakeRepository()),
          appVersionRepositoryProvider
              .overrideWithValue(_PendingRepository(completer)),
        ],
      );

      expect(find.byKey(_homeKey), findsOneWidget);
      expect(find.byType(AppUpdateRequiredScreen), findsNothing);
      completer.complete(null);
      await tester.pumpAndSettle();
    });
  });

  testAdaptiveWidgets('$AppUpdateRequiredScreen golden test',
      (tester, variant) async {
    await tester.pumpApp(
      AppUpdateRequiredScreen(onUpdate: () {}),
      windowConfig: variant,
    );
    await tester.pumpAndSettle();

    await tester.expectGolden<AppUpdateRequiredScreen>(variant);
  });

  testAdaptiveWidgets('$AppVersionGate recommendation dialog golden test',
      (tester, variant) async {
    await _pumpGate(
      tester,
      [
        ...homeScreenOverrides(),
        ..._overrides(_FakeRepository(policy: recommended)),
      ],
      // The home screen with its floating navigation bar, as in the app
      home: const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      windowConfig: variant,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle version disponible'), findsOneWidget);
    await tester.expectGolden<AppVersionGate>(variant, suffix: 'dialog');
  });
}

class _PendingRepository implements AppVersionRepository {
  _PendingRepository(this._completer);
  final Completer<AppVersionPolicy?> _completer;

  @override
  Future<AppVersionPolicy?> getPolicy(String platform) => _completer.future;
}
