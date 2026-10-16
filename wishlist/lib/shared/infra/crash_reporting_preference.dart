import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishlist/shared/infra/first_launch_service.dart';

/// User choice to send crash reports (opt-out, enabled by default).
class CrashReportingPreference {
  CrashReportingPreference(this._prefs);

  final SharedPreferences _prefs;

  static const String enabledKey = 'crash_reporting_enabled';

  bool isEnabled() => _prefs.getBool(enabledKey) ?? true;

  Future<void> setEnabled({required bool enabled}) async {
    await _prefs.setBool(enabledKey, enabled);
  }
}

class CrashReportingEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);

    return CrashReportingPreference(prefs).isEnabled();
  }

  /// Turning it off stops Sentry right away, turning it on only applies at the
  /// next launch since Sentry is initialized in `main`.
  Future<void> setEnabled({required bool enabled}) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await CrashReportingPreference(prefs).setEnabled(enabled: enabled);
    state = AsyncData(enabled);

    if (!enabled) {
      await Sentry.close();
    }
  }
}

final crashReportingEnabledProvider =
    AsyncNotifierProvider<CrashReportingEnabledNotifier, bool>(
  CrashReportingEnabledNotifier.new,
);
