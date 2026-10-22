import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wishlist/shared/infra/app_info_provider.dart';
import 'package:wishlist/shared/infra/app_version.dart';
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
/// Sentry warning.
typedef AppUpdateReporter = void Function(String message, {bool capture});

/// Sentry is only initialized in release builds with a DSN: elsewhere these
/// calls do nothing. The message holds no user data.
void reportAppUpdateIssue(String message, {bool capture = true}) {
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
    if (capture) {
      unawaited(
        Sentry.captureMessage(message, level: SentryLevel.warning)
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
  } catch (_) {
    // Reporting must never break the check.
  }
}

class AppUpdateService {
  AppUpdateService(
    this._repository, {
    AppUpdateReporter report = reportAppUpdateIssue,
  }) : _report = report;
  final AppVersionRepository _repository;
  final AppUpdateReporter _report;

  static const _timeout = Duration(seconds: 10);

  /// Null when the check failed (network, timeout, missing RPC, bad row...):
  /// the caller lets the user through. The failure is logged and reported to
  /// Sentry, never shown.
  Future<AppUpdateDecision?> check({
    required String currentVersion,
    required String platform,
  }) async {
    try {
      final policy = await _repository.getPolicy(platform).timeout(_timeout);
      if (policy == null) {
        debugPrint('[Wishy AppUpdate] no policy for $platform');
        _report('App version check: no policy row for $platform');
        return null;
      }
      return decideAppUpdate(currentVersion, policy);
    } catch (e) {
      debugPrint('[Wishy AppUpdate] check failed: $e');
      _report(
        'App version check failed ($platform): ${e.runtimeType}',
        capture: !isNetworkError(e),
      );
      return null;
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
  bool _isChecking = false;

  @override
  AppUpdateDecision build() => AppUpdateDecision.upToDate;

  /// Reads the app version and the server policy. A failed check keeps the
  /// previous result: it never blocks, and does not unblock either.
  Future<void> check() async {
    final platform = ref.read(appUpdatePlatformProvider);
    if (platform == null || _isChecking) {
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
