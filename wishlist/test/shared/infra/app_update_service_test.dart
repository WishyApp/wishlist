import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/app_update_service.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository.dart';
import 'package:wishlist/shared/models/app_version_policy.dart';

class _FakeRepository implements AppVersionRepository {
  _FakeRepository({this.policy, this.error, this.hangs = false});

  final AppVersionPolicy? policy;
  final Exception? error;
  final bool hangs;
  String? requestedPlatform;

  @override
  Future<AppVersionPolicy?> getPolicy(String platform) async {
    requestedPlatform = platform;
    if (hangs) {
      return Completer<AppVersionPolicy?>().future;
    }
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return policy;
  }
}

AppVersionPolicy policy({
  String min = '0.0.0',
  String recommended = '0.0.0',
  String? url = 'https://example.com/store',
}) =>
    AppVersionPolicy(
      minVersion: min,
      recommendedVersion: recommended,
      updateUrl: url,
    );

AppUpdateStatus statusOf(String? current, AppVersionPolicy policy) =>
    decideAppUpdate(current, policy).status;

void main() {
  group('decideAppUpdate', () {
    test('initial values 0.0.0 pass everybody', () {
      expect(statusOf('0.3.0', policy()), AppUpdateStatus.upToDate);
      expect(statusOf('0.0.0', policy()), AppUpdateStatus.upToDate);
    });

    test('below the minimum blocks, with the url', () {
      final decision = decideAppUpdate('0.2.0', policy(min: '0.3.0'));
      expect(decision.status, AppUpdateStatus.required);
      expect(decision.updateUrl, 'https://example.com/store');
    });

    test('the minimum itself is allowed', () {
      expect(
        statusOf('0.3.0', policy(min: '0.3.0')),
        AppUpdateStatus.upToDate,
      );
    });

    test('compares numerically', () {
      expect(
        statusOf('0.3.0', policy(min: '0.10.0')),
        AppUpdateStatus.required,
      );
      expect(
        statusOf('0.10.0', policy(min: '0.3.0')),
        AppUpdateStatus.upToDate,
      );
    });

    test('between minimum and recommended suggests', () {
      expect(
        statusOf('0.3.0', policy(min: '0.2.0', recommended: '0.4.0')),
        AppUpdateStatus.recommended,
      );
    });

    test('the minimum wins over the recommendation', () {
      expect(
        statusOf('0.1.0', policy(min: '0.2.0', recommended: '0.4.0')),
        AppUpdateStatus.required,
      );
    });

    test('at or above the recommended version passes', () {
      expect(
        statusOf('0.4.0', policy(min: '0.2.0', recommended: '0.4.0')),
        AppUpdateStatus.upToDate,
      );
    });

    test('build suffix of the app version is ignored', () {
      expect(
        statusOf('0.3.0+10', policy(min: '0.3.0')),
        AppUpdateStatus.upToDate,
      );
    });

    test('unparsable app version passes', () {
      expect(
        statusOf('garbage', policy(min: '9.0.0')),
        AppUpdateStatus.upToDate,
      );
      expect(statusOf(null, policy(min: '9.0.0')), AppUpdateStatus.upToDate);
      expect(statusOf('', policy(min: '9.0.0')), AppUpdateStatus.upToDate);
    });

    test('unparsable policy versions are ignored, each on its own', () {
      expect(statusOf('0.1.0', policy(min: 'x')), AppUpdateStatus.upToDate);
      expect(
        statusOf('0.1.0', policy(recommended: 'x')),
        AppUpdateStatus.upToDate,
      );
      expect(
        statusOf('0.1.0', policy(min: 'x', recommended: '0.2.0')),
        AppUpdateStatus.recommended,
      );
      expect(
        statusOf('0.1.0', policy(min: '0.2.0', recommended: 'x')),
        AppUpdateStatus.required,
      );
    });

    test('no, blank or non-http url gives a null url', () {
      for (final url in [null, '', '  ', 'javascript:alert(1)', 'not a url']) {
        expect(
          decideAppUpdate('0.1.0', policy(min: '0.2.0', url: url)).updateUrl,
          isNull,
          reason: '$url',
        );
      }
    });
  });

  group('AppUpdateService.check', () {
    test('asks the repository for the platform and decides', () async {
      final repository = _FakeRepository(policy: policy(min: '0.3.0'));
      final decision = await AppUpdateService(repository)
          .check(currentVersion: '0.2.0', platform: 'ios');

      expect(repository.requestedPlatform, 'ios');
      expect(decision?.status, AppUpdateStatus.required);
    });

    test('returns null when the repository throws', () async {
      final decision = await AppUpdateService(
        _FakeRepository(error: Exception('network down')),
      ).check(currentVersion: '0.2.0', platform: 'ios');

      expect(decision, isNull);
    });

    test('returns null when there is no policy row', () async {
      final decision = await AppUpdateService(_FakeRepository())
          .check(currentVersion: '0.2.0', platform: 'ios');

      expect(decision, isNull);
    });
  });

  group('AppUpdateService reporting', () {
    final reports = <({String message, bool capture, String? kind})>[];
    setUp(reports.clear);

    AppUpdateService service(AppVersionRepository repository) =>
        AppUpdateService(
          repository,
          report: (message, {capture = true, kind}) =>
              reports.add((message: message, capture: capture, kind: kind)),
        );

    test('no policy row is reported to Sentry', () async {
      await service(_FakeRepository())
          .check(currentVersion: '0.2.0', platform: 'ios');

      expect(reports, hasLength(1));
      expect(reports.single.capture, isTrue);
      expect(reports.single.message, contains('no policy row'));
    });

    test('an unexpected failure is reported to Sentry', () async {
      await service(_FakeRepository(error: const FormatException('x')))
          .check(currentVersion: '0.2.0', platform: 'ios');

      expect(reports.single.capture, isTrue);
      expect(reports.single.message, contains('FormatException'));
    });

    test('a PostgrestException report has its code and message', () async {
      await service(
        _FakeRepository(
          error: const PostgrestException(
            message: 'function not found',
            code: 'PGRST202',
          ),
        ),
      ).check(currentVersion: '0.2.0', platform: 'ios');

      expect(reports.single.message, contains('PGRST202'));
      expect(reports.single.message, contains('function not found'));
      expect(reports.single.kind, 'PostgrestException/PGRST202');
    });

    test('looks through the AppException of executeSafely', () async {
      await service(
        _FakeRepository(
          error: AppException(
            statusCode: 500,
            cause: const PostgrestException(message: 'denied', code: '42501'),
          ),
        ),
      ).check(currentVersion: '0.2.0', platform: 'ios');

      expect(reports.single.message, contains('42501'));
      expect(reports.single.capture, isTrue);
    });

    test('a wrapped network failure only leaves a breadcrumb', () async {
      await service(
        _FakeRepository(
          error: AppException(
            statusCode: 500,
            cause: const SocketException('down'),
          ),
        ),
      ).check(currentVersion: '0.2.0', platform: 'ios');

      expect(reports.single.capture, isFalse);
    });

    test('a network failure only leaves a breadcrumb', () async {
      await service(_FakeRepository(error: const SocketException('down')))
          .check(currentVersion: '0.2.0', platform: 'ios');

      expect(reports.single.capture, isFalse);
    });

    test('a gateway timeout (504) only leaves a breadcrumb', () async {
      await service(
        _FakeRepository(
          error: AppException(
            statusCode: 500,
            cause: const PostgrestException(message: '', code: '504'),
          ),
        ),
      ).check(currentVersion: '0.2.0', platform: 'android');

      expect(reports.single.capture, isFalse);
      expect(reports.single.message, contains('504'));
    });

    test('a 4xx from the server is still reported to Sentry', () async {
      await service(
        _FakeRepository(
          error: const PostgrestException(message: 'bad', code: '400'),
        ),
      ).check(currentVersion: '0.2.0', platform: 'android');

      expect(reports.single.capture, isTrue);
    });

    test('a success reports nothing', () async {
      await service(_FakeRepository(policy: policy()))
          .check(currentVersion: '0.2.0', platform: 'ios');

      expect(reports, isEmpty);
    });

    testWidgets('a hung request times out after 10 seconds: pass, breadcrumb',
        (tester) async {
      AppUpdateDecision? decision;
      var done = false;
      unawaited(
        service(_FakeRepository(hangs: true))
            .check(currentVersion: '0.2.0', platform: 'ios')
            .then((d) {
          decision = d;
          done = true;
        }),
      );

      await tester.pump(const Duration(seconds: 9));
      expect(done, isFalse);
      await tester.pump(const Duration(seconds: 2));

      expect(done, isTrue);
      expect(decision, isNull);
      expect(reports.single.capture, isFalse);
    });
  });

  group('reportAppUpdateIssue', () {
    final sent = <String>[];
    final original = captureAppUpdateMessage;

    setUp(() {
      sent.clear();
      capturedAppUpdateKinds.clear();
      captureAppUpdateMessage = (message) async => sent.add(message);
    });
    tearDown(() => captureAppUpdateMessage = original);

    test('sends a given kind to Sentry once per session', () {
      reportAppUpdateIssue('first', kind: 'a');
      reportAppUpdateIssue('second', kind: 'a');
      reportAppUpdateIssue('third', kind: 'b');

      expect(sent, ['first', 'third']);
    });

    test('a breadcrumb-only report sends nothing and keeps the kind free', () {
      reportAppUpdateIssue('network', capture: false, kind: 'a');
      reportAppUpdateIssue('real', kind: 'a');

      expect(sent, ['real']);
    });

    test('a failing capture does not throw', () {
      captureAppUpdateMessage = (_) => Future.error(StateError('boom'));

      expect(() => reportAppUpdateIssue('x'), returnsNormally);
    });
  });

  group('AppVersionPolicy.fromRow', () {
    test('reads a row, url included or null', () {
      final withUrl = AppVersionPolicy.fromRow(const {
        'min_version': '0.1.0',
        'recommended_version': '0.2.0',
        'update_url': 'https://example.com',
      });
      expect(withUrl.minVersion, '0.1.0');
      expect(withUrl.recommendedVersion, '0.2.0');
      expect(withUrl.updateUrl, 'https://example.com');

      final withoutUrl = AppVersionPolicy.fromRow(const {
        'min_version': '0.1.0',
        'recommended_version': '0.2.0',
        'update_url': null,
      });
      expect(withoutUrl.updateUrl, isNull);
    });

    test('throws on a malformed row, which the service turns into a pass', () {
      expect(
        () => AppVersionPolicy.fromRow(const {'min_version': 3}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
