import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wishlist/app/version_gate/app_version_gate.dart';
import 'package:wishlist/shared/infra/app_info_provider.dart';
import 'package:wishlist/shared/infra/app_update_service.dart';
import 'package:wishlist/shared/infra/in_app_updater.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository_provider.dart';
import 'package:wishlist/shared/models/app_version_policy.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../pump_app.dart';

class _FakeUpdater implements InAppUpdater {
  _FakeUpdater({
    this.available = true,
    this.checkError,
    this.result = InAppUpdateResult.done,
    this.performError,
  });

  final bool available;
  final Exception? checkError;
  final InAppUpdateResult result;
  final Exception? performError;
  int immediateCalls = 0;
  int flexibleCalls = 0;

  @override
  Future<bool> isUpdateAvailable() async {
    final error = checkError;
    if (error != null) {
      throw error;
    }
    return available;
  }

  @override
  Future<InAppUpdateResult> performImmediateUpdate() async {
    immediateCalls++;
    final error = performError;
    if (error != null) {
      throw error;
    }
    return result;
  }

  @override
  Future<InAppUpdateResult> performFlexibleUpdate() async {
    flexibleCalls++;
    final error = performError;
    if (error != null) {
      throw error;
    }
    return result;
  }
}

class _FakeRepository implements AppVersionRepository {
  _FakeRepository(this.policy);
  final AppVersionPolicy policy;

  @override
  Future<AppVersionPolicy?> getPolicy(String platform) async => policy;
}

const _url = 'https://example.com/store';
const _required = AppVersionPolicy(
  minVersion: '0.3.0',
  recommendedVersion: '0.3.0',
  updateUrl: _url,
);
const _recommended = AppVersionPolicy(
  minVersion: '0.1.0',
  recommendedVersion: '0.3.0',
  updateUrl: _url,
);

Future<void> _pumpGate(
  WidgetTester tester,
  AppVersionPolicy policy,
  _FakeUpdater updater,
  List<String> opened,
) async {
  // As in app.dart: builder of MaterialApp.router, above the Navigator that
  // shows the recommendation dialog.
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpRouterApp(
    '/',
    navigatorKey: navigatorKey,
    routes: [GoRoute(path: '/', builder: (_, __) => const Scaffold())],
    overrides: [
      appVersionRepositoryProvider.overrideWithValue(_FakeRepository(policy)),
      appUpdatePlatformProvider.overrideWithValue('android'),
      inAppUpdaterProvider.overrideWithValue(updater),
      appInfoProvider.overrideWith(
        (ref) async => PackageInfo(
          appName: 'Wishy',
          packageName: 'com.example.wishlist',
          version: '0.2.0',
          buildNumber: '1',
        ),
      ),
      appUpdateUrlLauncherProvider.overrideWithValue(
        (url) async => opened.add(url),
      ),
    ],
    builder: (context, child) =>
        AppVersionGate(navigatorKey: navigatorKey, child: child!),
  );
  // Post-frame check, then the repository future
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  group('blocking screen', () {
    testWidgets('runs the immediate flow when an update is available',
        (tester) async {
      final updater = _FakeUpdater();
      final opened = <String>[];
      await _pumpGate(tester, _required, updater, opened);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(updater.immediateCalls, 1);
      expect(updater.flexibleCalls, 0);
      expect(opened, isEmpty);
    });

    testWidgets('a cancelled flow stays on the wall, no store page',
        (tester) async {
      final updater = _FakeUpdater(result: InAppUpdateResult.cancelled);
      final opened = <String>[];
      await _pumpGate(tester, _required, updater, opened);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(updater.immediateCalls, 1);
      expect(opened, isEmpty);
      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    for (final entry in {
      'no update available': _FakeUpdater(available: false),
      'the check throws': _FakeUpdater(checkError: Exception('not from Play')),
      'the flow throws': _FakeUpdater(performError: Exception('boom')),
      'the flow fails': _FakeUpdater(result: InAppUpdateResult.failed),
    }.entries) {
      testWidgets('falls back to the url when ${entry.key}', (tester) async {
        final opened = <String>[];
        await _pumpGate(tester, _required, entry.value, opened);

        await tester.tap(find.byType(PrimaryButton));
        await tester.pump();

        expect(opened, [_url]);
      });
    }
  });

  group('recommendation dialog', () {
    testWidgets('runs the flexible flow when an update is available',
        (tester) async {
      final updater = _FakeUpdater();
      final opened = <String>[];
      await _pumpGate(tester, _recommended, updater, opened);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(updater.flexibleCalls, 1);
      expect(updater.immediateCalls, 0);
      expect(opened, isEmpty);
    });

    testWidgets('falls back to the url when no update is available',
        (tester) async {
      final opened = <String>[];
      await _pumpGate(
        tester,
        _recommended,
        _FakeUpdater(available: false),
        opened,
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(opened, [_url]);
    });

    testWidgets('falls back to the url when the flow throws', (tester) async {
      final opened = <String>[];
      await _pumpGate(
        tester,
        _recommended,
        _FakeUpdater(performError: Exception('boom')),
        opened,
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(opened, [_url]);
    });
  });

  group('inAppUpdaterProvider', () {
    InAppUpdater read({required bool enabled, required String? platform}) {
      final container = ProviderContainer(
        overrides: [
          playInAppUpdatesEnabledProvider.overrideWithValue(enabled),
          appUpdatePlatformProvider.overrideWithValue(platform),
        ],
      );
      addTearDown(container.dispose);
      return container.read(inAppUpdaterProvider);
    }

    test('is off by default (compile-time switch)', () {
      expect(kPlayInAppUpdatesEnabled, isFalse);
    });

    test('Play only on Android with the switch on', () {
      expect(
        read(enabled: true, platform: 'android'),
        isA<PlayInAppUpdater>(),
      );
    });

    test('no-op when the switch is off', () {
      expect(
        read(enabled: false, platform: 'android'),
        isA<NoopInAppUpdater>(),
      );
    });

    test('no-op on iOS and other platforms', () {
      expect(read(enabled: true, platform: 'ios'), isA<NoopInAppUpdater>());
      expect(read(enabled: true, platform: null), isA<NoopInAppUpdater>());
    });
  });

  group('runAppUpdate with the no-op updater (switch off / iOS)', () {
    test('opens the store', () async {
      var opened = 0;
      await runAppUpdate(
        updater: const NoopInAppUpdater(),
        mode: AppUpdateMode.immediate,
        openStore: () => opened++,
      );
      expect(opened, 1);
    });

    test('without url, does nothing and does not throw', () async {
      await runAppUpdate(
        updater: const NoopInAppUpdater(),
        mode: AppUpdateMode.flexible,
        openStore: null,
      );
    });
  });
}
