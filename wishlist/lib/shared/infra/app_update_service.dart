import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/app_info_provider.dart';
import 'package:wishlist/shared/infra/app_version.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository_provider.dart';
import 'package:wishlist/shared/infra/utils/network_error.dart';
import 'package:wishlist/shared/models/app_version_policy.dart';

enum AppUpdateStatus {
  /// Nothing to say: up to date, or the check could not tell.
  upToDate,

  /// Older than the recommended version: suggest the update.
  recommended,

  /// Older than the minimum version: the app must not be used.
  required,
}

@immutable
class AppUpdateDecision {
  const AppUpdateDecision(this.status, {this.updateUrl});

  static const upToDate = AppUpdateDecision(AppUpdateStatus.upToDate);

  final AppUpdateStatus status;

  /// Store page of the update, when the server gives one.
  final String? updateUrl;

  @override
  bool operator ==(Object other) =>
      other is AppUpdateDecision &&
      other.status == status &&
      other.updateUrl == updateUrl;

  @override
  int get hashCode => Object.hash(status, updateUrl);
}

/// Compares [currentVersion] with [policy]. A version that cannot be parsed
/// (the app's, or one of the policy) never blocks nor nags: it is ignored.
AppUpdateDecision decideAppUpdate(
  String? currentVersion,
  AppVersionPolicy policy,
) {
  final current = AppVersion.tryParse(currentVersion);
  if (current == null) {
    return AppUpdateDecision.upToDate;
  }
  final min = AppVersion.tryParse(policy.minVersion);
  final recommended = AppVersion.tryParse(policy.recommendedVersion);
  final url = _cleanUrl(policy.updateUrl);

  if (min != null && current < min) {
    return AppUpdateDecision(AppUpdateStatus.required, updateUrl: url);
  }
  if (recommended != null && current < recommended) {
    return AppUpdateDecision(AppUpdateStatus.recommended, updateUrl: url);
  }
  return AppUpdateDecision.upToDate;
}

String? _cleanUrl(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  final isWeb = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  return isWeb ? trimmed : null;
}

/// Reports a version check problem. [capture] false only leaves a breadcrumb
/// (expected, frequent failures like a missing network); true also sends a
/// Sentry warning, at most once per app session for a given [kind].
typedef AppUpdateReporter = void Function(
  String message, {
  bool capture,
  String? kind,
});

/// Kinds already sent to Sentry in this session.
@visibleForTesting
final capturedAppUpdateKinds = <String>{};

/// Sends a warning to Sentry. Replaced in tests.
@visibleForTesting
Future<void> Function(String message) captureAppUpdateMessage = (message) =>
    Sentry.captureMessage(message, level: SentryLevel.warning)
        .then<void>((_) {});

/// Sentry is only initialized in release builds with a DSN: elsewhere these
/// calls do nothing. The message holds no user data.
void reportAppUpdateIssue(
  String message, {
  bool capture = true,
  String? kind,
}) {
  try {
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          category: 'app_update',
          level: SentryLevel.warning,
        ),
      ),
    );
    if (capture && capturedAppUpdateKinds.add(kind ?? message)) {
      unawaited(captureAppUpdateMessage(message).catchError((Object _) {}));
    }
  } catch (_) {
    // Reporting must never break the check.
  }
}

/// `PostgrestException` code and message tell a missing function (PGRST202)
/// from a denied permission (42501): kept in the report, which otherwise only
/// has the type. Looks through [AppException.cause].
({String kind, String text}) _describeFailure(Object error) {
  final cause = unwrapCause(error);
  if (cause is PostgrestException) {
    return (
      kind: 'PostgrestException/${cause.code}',
      text: 'PostgrestException code=${cause.code} message=${cause.message}',
    );
  }
  return (kind: '${cause.runtimeType}', text: '${cause.runtimeType}');
}

class AppUpdateService {
  AppUpdateService(
    this._repository, {
    AppUpdateReporter report = reportAppUpdateIssue,
    this.retryDelay = const Duration(seconds: 3),
  }) : _report = report;
  final AppVersionRepository _repository;
  final AppUpdateReporter _report;

  /// Wait before the single retry after a passing server error (502, 503,
  /// 504): otherwise a user below the minimum version could use the app until
  /// its next return to the foreground.
  final Duration retryDelay;

  static const _timeout = Duration(seconds: 10);

  /// The first try and the retry after a passing server error.
  static const _maxAttempts = 2;

  /// Null when the check failed (network, timeout, missing RPC, bad row...):
  /// the caller lets the user through. The failure is logged and reported to
  /// Sentry, never shown; a passing failure (network, gateway 5xx) only leaves
  /// a breadcrumb. A passing server error is retried once after [retryDelay],
  /// and any failure of that retry is reported.
  Future<AppUpdateDecision?> check({
    required String currentVersion,
    required String platform,
  }) async {
    for (var attempt = 1;; attempt++) {
      try {
        final policy = await _repository.getPolicy(platform).timeout(_timeout);
        if (policy == null) {
          debugPrint('[Wishy AppUpdate] no policy for $platform');
          _report(
            'App version check: no policy row for $platform',
            kind: 'no_policy_row',
          );
          return null;
        }
        return decideAppUpdate(currentVersion, policy);
      } catch (e) {
        debugPrint('[Wishy AppUpdate] check failed: $e');
        final willRetry = isTransientServerError(e) && attempt < _maxAttempts;
        final failure = _describeFailure(e);
        _report(
          'App version check failed ($platform): ${failure.text}',
          // A retry that fails too, even on a timeout, may be an outage
          capture: !willRetry && (attempt > 1 || !isNetworkError(e)),
          kind: failure.kind,
        );
        if (!willRetry) {
          return null;
        }
        await Future<void>.delayed(retryDelay);
      }
    }
  }
}

final appUpdateServiceProvider = Provider.autoDispose(
  (ref) => AppUpdateService(ref.watch(appVersionRepositoryProvider)),
);

/// Platform name of the server policy (`ios`, `android`). Null elsewhere
/// (web, desktop): no check.
final appUpdatePlatformProvider = Provider<String?>((ref) {
  if (kIsWeb) {
    return null;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => null,
  };
});

/// Opens the store page. Overridable in tests.
final appUpdateUrlLauncherProvider = Provider<Future<void> Function(String)>(
  (ref) => (url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[Wishy AppUpdate] cannot open $url: $e');
    }
  },
);

/// Result of the last version check. Starts as "up to date": nothing is
/// shown until a check says otherwise.
class AppUpdateNotifier extends Notifier<AppUpdateDecision> {
  /// A check that succeeded less than this ago is not repeated on resume: the
  /// policy changes a few times a year.
  static const resumeThrottle = Duration(minutes: 5);

  bool _isChecking = false;
  DateTime? _lastSuccessAt;

  @override
  AppUpdateDecision build() => AppUpdateDecision.upToDate;

  /// Reads the app version and the server policy. A failed check keeps the
  /// previous result: it never blocks, and does not unblock either.
  ///
  /// Unless [force] (launch), does nothing when the last successful check is
  /// less than [resumeThrottle] old.
  Future<void> check({bool force = false}) async {
    final platform = ref.read(appUpdatePlatformProvider);
    if (platform == null || _isChecking) {
      return;
    }
    final now = ref.read(clockProvider)();
    final lastSuccessAt = _lastSuccessAt;
    if (!force &&
        lastSuccessAt != null &&
        now.difference(lastSuccessAt) < resumeThrottle) {
      return;
    }
    _isChecking = true;
    try {
      final PackageInfo info;
      try {
        info = await ref.read(appInfoProvider.future);
      } catch (e) {
        debugPrint('[Wishy AppUpdate] cannot read the app version: $e');
        return;
      }
      final decision = await ref.read(appUpdateServiceProvider).check(
            currentVersion: info.version,
            platform: platform,
          );
      if (decision != null) {
        _lastSuccessAt = now;
        state = decision;
      }
    } finally {
      _isChecking = false;
    }
  }
}

final appUpdateProvider =
    NotifierProvider<AppUpdateNotifier, AppUpdateDecision>(
  AppUpdateNotifier.new,
);
