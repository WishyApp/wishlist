import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:wishlist/shared/infra/app_update_service.dart';

/// Compile-time switch of the Google Play in-app updates. Off by default: the
/// app ships inert and keeps opening the store page, as before. To turn on
/// once the app is on the Play Store:
/// `flutter build appbundle --dart-define=PLAY_IN_APP_UPDATES=true`.
const bool kPlayInAppUpdatesEnabled = bool.fromEnvironment(
  'PLAY_IN_APP_UPDATES',
);

/// How a started in-app update ended.
enum InAppUpdateResult {
  /// The update went through (immediate), or is downloaded and installing
  /// (flexible).
  done,

  /// The user closed the Play dialog: nothing more to do, no fallback.
  cancelled,

  /// Play could not do it: the caller falls back to the store page.
  failed,
}

/// Updates the app without leaving it. Implementations never throw out of
/// [isUpdateAvailable]; the caller still guards the other methods.
abstract class InAppUpdater {
  /// True only when Play says an update can be installed from here (so false
  /// when the app was not installed from Play, or is up to date).
  Future<bool> isUpdateAvailable();

  /// Full-screen Play flow, blocks the app until it ends.
  Future<InAppUpdateResult> performImmediateUpdate();

  /// Downloads in the background, then restarts the app on the new version
  /// as soon as the download is finished.
  Future<InAppUpdateResult> performFlexibleUpdate();
}

/// Does nothing: the store page fallback is used.
class NoopInAppUpdater implements InAppUpdater {
  const NoopInAppUpdater();

  @override
  Future<bool> isUpdateAvailable() async => false;

  @override
  Future<InAppUpdateResult> performImmediateUpdate() async =>
      InAppUpdateResult.failed;

  @override
  Future<InAppUpdateResult> performFlexibleUpdate() async =>
      InAppUpdateResult.failed;
}

/// Google Play implementation (Android only), on top of `in_app_update`.
class PlayInAppUpdater implements InAppUpdater {
  const PlayInAppUpdater();

  static const _flexibleDownloadTimeout = Duration(minutes: 30);

  @override
  Future<bool> isUpdateAvailable() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (e) {
      debugPrint('[Wishy InAppUpdate] check failed: $e');
      return false;
    }
  }

  @override
  Future<InAppUpdateResult> performImmediateUpdate() async {
    return _map(await InAppUpdate.performImmediateUpdate());
  }

  @override
  Future<InAppUpdateResult> performFlexibleUpdate() async {
    // Listen before starting so the "downloaded" event cannot be missed.
    final downloaded = Completer<bool>();
    final subscription = InAppUpdate.installUpdateListener.listen((status) {
      if (downloaded.isCompleted) {
        return;
      }
      if (status == InstallStatus.downloaded) {
        downloaded.complete(true);
      } else if (status == InstallStatus.failed ||
          status == InstallStatus.canceled) {
        downloaded.complete(false);
      }
    });
    try {
      final started = _map(await InAppUpdate.startFlexibleUpdate());
      if (started != InAppUpdateResult.done) {
        return started;
      }
      final ok = await downloaded.future.timeout(
        _flexibleDownloadTimeout,
        onTimeout: () => false,
      );
      if (!ok) {
        return InAppUpdateResult.failed;
      }
      await InAppUpdate.completeFlexibleUpdate();
      return InAppUpdateResult.done;
    } finally {
      await subscription.cancel();
    }
  }

  InAppUpdateResult _map(AppUpdateResult result) => switch (result) {
        AppUpdateResult.success => InAppUpdateResult.done,
        AppUpdateResult.userDeniedUpdate => InAppUpdateResult.cancelled,
        AppUpdateResult.inAppUpdateFailed => InAppUpdateResult.failed,
      };
}

/// Whether the in-app updates are on. Overridable in tests.
final playInAppUpdatesEnabledProvider = Provider<bool>(
  (ref) => kPlayInAppUpdatesEnabled,
);

/// The updater to use: Play on Android when the switch is on, a no-op
/// otherwise. Overridable in tests.
final inAppUpdaterProvider = Provider<InAppUpdater>((ref) {
  final isAndroid = ref.watch(appUpdatePlatformProvider) == 'android';
  if (ref.watch(playInAppUpdatesEnabledProvider) && isAndroid) {
    return const PlayInAppUpdater();
  }
  return const NoopInAppUpdater();
});

enum AppUpdateMode {
  /// Blocking screen: Play's full-screen flow.
  immediate,

  /// Banner: background download.
  flexible,
}

/// Runs the "Mettre à jour" action: the Play in-app flow when possible,
/// otherwise [openStore] with the server's `update_url`. Never throws, and a
/// cancelled Play dialog does not open the store.
Future<void> runAppUpdate({
  required InAppUpdater updater,
  required AppUpdateMode mode,
  required VoidCallback? openStore,
}) async {
  try {
    if (await updater.isUpdateAvailable()) {
      final result = switch (mode) {
        AppUpdateMode.immediate => await updater.performImmediateUpdate(),
        AppUpdateMode.flexible => await updater.performFlexibleUpdate(),
      };
      if (result != InAppUpdateResult.failed) {
        return;
      }
    }
  } catch (e) {
    debugPrint('[Wishy InAppUpdate] failed, falling back to the store: $e');
  }
  openStore?.call();
}
