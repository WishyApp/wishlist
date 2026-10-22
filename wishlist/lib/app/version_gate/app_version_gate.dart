import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/app/version_gate/app_update_required_screen.dart';
import 'package:wishlist/app/version_gate/update_text_variant.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/app_update_service.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/widgets/dialogs/app_dialog.dart';

/// Wraps the whole app (see `MaterialApp.router`'s builder, so it covers the
/// sign in screens too) and applies the server's version policy:
///
/// - older than the minimum: [AppUpdateRequiredScreen] replaces the app. The
///   child is not built, so there is no navigation behind it. The system back
///   button is left alone: the router has no Navigator left to pop, nobody
///   handles it and the app exits, as from any root screen.
/// - older than the recommended version: a dialog, once per app session.
///
/// The policy is read at launch and each time the app comes back to the
/// foreground.
class AppVersionGate extends ConsumerStatefulWidget {
  const AppVersionGate({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;

  /// Key of the router's Navigator, which shows the recommendation dialog.
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends ConsumerState<AppVersionGate>
    with WidgetsBindingObserver {
  bool _recommendationShown = false;

  /// Route of the recommendation dialog, to remove it and nothing else.
  Route<void>? _dialogRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(force: true));
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

  Future<void> _check({bool force = false}) async {
    if (!mounted) {
      return;
    }
    await ref.read(appUpdateProvider.notifier).check(force: force);
    if (mounted) {
      _showRecommendation();
    }
  }

  void _openStore(String url) {
    ref.read(appUpdateUrlLauncherProvider)(url);
  }

  /// Once per app session, over the router's Navigator (this widget is above
  /// it, so its own context cannot show a dialog). Skipped silently while that
  /// Navigator does not exist yet: the next check tries again.
  void _showRecommendation() {
    final decision = ref.read(appUpdateProvider);
    final context = widget.navigatorKey.currentContext;
    if (decision.status != AppUpdateStatus.recommended ||
        _recommendationShown ||
        (_dialogRoute?.isActive ?? false) ||
        context == null) {
      return;
    }
    _recommendationShown = true;

    final l10n = context.l10n;
    final url = decision.updateUrl;
    final description = switch (UpdateTextVariant.of(
      hasLink: url != null,
      platform: ref.read(appUpdatePlatformProvider),
    )) {
      UpdateTextVariant.iosStore => l10n.updateAvailableNoLinkIosMessage,
      UpdateTextVariant.androidStore =>
        l10n.updateAvailableNoLinkAndroidMessage,
      UpdateTextVariant.generic => l10n.updateAvailableMessage,
    };

    unawaited(
      showAppDialog(
        context,
        title: l10n.updateAvailableTitle,
        content: Builder(
          builder: (dialogContext) {
            // The only way to get the route showAppDialog pushes
            _dialogRoute = ModalRoute.of(dialogContext) as Route<void>?;
            return Text(
              description,
              style: AppTextStyles.small.copyWith(color: AppColors.makara),
            );
          },
        ),
        confirmButtonLabel: l10n.updateButton,
        cancelButtonLabel: l10n.updateLaterButton,
        onCancel: () {},
        // No confirm button without a store page
        onConfirm: url == null ? null : () async => _openStore(url),
      ),
    );
  }

  /// Removes the dialog's own route: a page opened above it (a share, a
  /// deep link) stays, and a dialog already gone is not "closed" again, which
  /// would pop a real page.
  void _closeDialog() {
    final route = _dialogRoute;
    _dialogRoute = null;
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateProvider, (_, decision) {
      switch (decision.status) {
        case AppUpdateStatus.required:
          // The wall replaces the app, Navigator and dialog route included:
          // nothing to remove.
          _dialogRoute = null;
        case AppUpdateStatus.upToDate:
          _closeDialog();
        case AppUpdateStatus.recommended:
          break;
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
