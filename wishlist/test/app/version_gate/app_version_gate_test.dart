import 'dart:async';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wishlist/app/version_gate/app_update_required_screen.dart';
import 'package:wishlist/app/version_gate/app_version_gate.dart';
import 'package:wishlist/shared/infra/app_info_provider.dart';
import 'package:wishlist/shared/infra/app_update_service.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository_provider.dart';
import 'package:wishlist/shared/models/app_version_policy.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../pump_app.dart';

class _FakeRepository implements AppVersionRepository {
  _FakeRepository({this.policy, this.error});

  AppVersionPolicy? policy;
  Exception? error;
  int calls = 0;

  @override
  Future<AppVersionPolicy?> getPolicy(String platform) async {
    calls++;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return policy;
  }
}

const _homeKey = Key('home');

List<Override> _overrides(
  _FakeRepository repository, {
  String appVersion = '0.2.0',
  String? platform = 'ios',
  List<String>? openedUrls,
}) {
  return [
    appVersionRepositoryProvider.overrideWithValue(repository),
    appUpdatePlatformProvider.overrideWithValue(platform),
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

Future<void> _pumpGate(
  WidgetTester tester,
  List<Override> overrides,
) async {
  await tester.pumpApp(
    const SizedBox.shrink(),
    overrides: overrides,
    // Same spot as in app.dart: MaterialApp's builder
    appBuilder: (context, child) => AppVersionGate(
      child: Scaffold(key: _homeKey, body: child),
    ),
  );
  // Post-frame check, then the repository future
  await tester.pump();
  await tester.pump();
}

void main() {
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
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('cannot be dismissed: no app bar, back button swallowed',
        (tester) async {
      await _pumpGate(tester, _overrides(_FakeRepository(policy: required)));

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackButton), findsNothing);

      final handled = await tester.binding.handlePopRoute();
      await tester.pump();

      expect(handled, isTrue);
      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);
    });

    testWidgets('is shown again when the app comes back to the foreground',
        (tester) async {
      final repository = _FakeRepository(policy: required);
      await _pumpGate(tester, _overrides(repository));
      expect(repository.calls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(repository.calls, 2);
      expect(find.byType(AppUpdateRequiredScreen), findsOneWidget);
    });

    testWidgets('a failed re-check does not unblock', (tester) async {
      final repository = _FakeRepository(policy: required);
      await _pumpGate(tester, _overrides(repository));

      repository.error = Exception('offline');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(find.byType(AppUpdateRequiredScreen), findsNothing);
      expect(find.byKey(_homeKey), findsOneWidget);
    });
  });

  group('recommendation banner', () {
    testWidgets('is shown, dismissible, and the app stays usable',
        (tester) async {
      await _pumpGate(
        tester,
        _overrides(_FakeRepository(policy: recommended)),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(_homeKey), findsOneWidget);
      expect(find.byType(AppUpdateRequiredScreen), findsNothing);
      expect(
        find.text('Une nouvelle version de Wishy est disponible.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      expect(
        find.text('Une nouvelle version de Wishy est disponible.'),
        findsNothing,
      );
    });

    testWidgets('is shown only once per session', (tester) async {
      final repository = _FakeRepository(policy: recommended);
      await _pumpGate(tester, _overrides(repository));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(
        find.text('Une nouvelle version de Wishy est disponible.'),
        findsNothing,
      );
    });

    testWidgets('the update action opens the url', (tester) async {
      final opened = <String>[];
      await _pumpGate(
        tester,
        _overrides(_FakeRepository(policy: recommended), openedUrls: opened),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Mettre à jour'));
      await tester.pumpAndSettle();

      expect(opened, ['https://example.com/store']);
    });

    testWidgets('without url there is only the dismiss action', (tester) async {
      await _pumpGate(
        tester,
        _overrides(
          _FakeRepository(
            policy: const AppVersionPolicy(
              minVersion: '0.1.0',
              recommendedVersion: '0.3.0',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Plus tard'), findsOneWidget);
      expect(find.text('Mettre à jour'), findsNothing);
    });
  });

  group('lets the user through', () {
    Future<void> expectNothingShown(WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byKey(_homeKey), findsOneWidget);
      expect(find.byType(AppUpdateRequiredScreen), findsNothing);
      expect(find.byType(MaterialBanner), findsNothing);
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
}

class _PendingRepository implements AppVersionRepository {
  _PendingRepository(this._completer);
  final Completer<AppVersionPolicy?> _completer;

  @override
  Future<AppVersionPolicy?> getPolicy(String platform) => _completer.future;
}
