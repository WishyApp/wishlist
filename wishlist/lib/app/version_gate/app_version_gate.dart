import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/app/version_gate/app_update_required_screen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/app_update_service.dart';

/// Wraps the whole app (see `MaterialApp.router`'s builder, so it covers the
/// sign in screens too) and applies the server's version policy:
///
/// - older than the minimum: [AppUpdateRequiredScreen] replaces the app. The
///   child is not built, so there is no navigation behind it. The system back
///   button is left alone: the router has no Navigator left to pop, nobody
///   handles it and the app exits, as from any root screen.
/// - older than the recommended version: a dismissible banner, once per app
///   session.
///
/// The policy is read at launch and each time the app comes back to the
/// foreground.
class AppVersionGate extends ConsumerStatefulWidget {
  const AppVersionGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends ConsumerState<AppVersionGate>
    with WidgetsBindingObserver {
  bool _recommendationShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  void _check() {
    if (mounted) {
      ref.read(appUpdateProvider.notifier).check();
    }
  }

  void _openStore(String url) {
    ref.read(appUpdateUrlLauncherProvider)(url);
  }

  void _showRecommendation(String? updateUrl) {
    _recommendationShown = true;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(l10n.updateAvailableMessage),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: Text(l10n.updateLaterButton),
          ),
          if (updateUrl != null)
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                _openStore(updateUrl);
              },
              child: Text(l10n.updateButton),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateProvider, (_, decision) {
      switch (decision.status) {
        case AppUpdateStatus.required:
          ScaffoldMessenger.of(context).clearMaterialBanners();
        case AppUpdateStatus.recommended:
          if (!_recommendationShown) {
            _showRecommendation(decision.updateUrl);
          }
        case AppUpdateStatus.upToDate:
          ScaffoldMessenger.of(context).clearMaterialBanners();
      }
    });

    final decision = ref.watch(appUpdateProvider);
    if (decision.status == AppUpdateStatus.required) {
      final url = decision.updateUrl;
      return AppUpdateRequiredScreen(
        platform: ref.read(appUpdatePlatformProvider),
        onUpdate: url == null ? null : () => _openStore(url),
      );
    }
    return widget.child;
  }
}
