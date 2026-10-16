import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishlist/shared/infra/crash_reporting_preference.dart';

import '../../fixtures/fake_providers.dart';

void main() {
  group('CrashReportingPreference', () {
    test('is enabled by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(CrashReportingPreference(prefs).isEnabled(), isTrue);
    });

    test('persists the toggle', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final preference = CrashReportingPreference(prefs);

      await preference.setEnabled(enabled: false);
      expect(preference.isEnabled(), isFalse);
      expect(prefs.getBool(CrashReportingPreference.enabledKey), isFalse);

      await preference.setEnabled(enabled: true);
      expect(preference.isEnabled(), isTrue);
    });
  });

  group('crashReportingEnabledProvider', () {
    test('defaults to true then follows the toggle', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesOverride()],
      );
      addTearDown(container.dispose);

      expect(await container.read(crashReportingEnabledProvider.future), true);

      await container
          .read(crashReportingEnabledProvider.notifier)
          .setEnabled(enabled: false);

      expect(container.read(crashReportingEnabledProvider).value, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(CrashReportingPreference.enabledKey), false);
    });

    test('reads a persisted opt-out', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesOverride(
            values: {CrashReportingPreference.enabledKey: false},
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(crashReportingEnabledProvider.future), false);
    });
  });
}
