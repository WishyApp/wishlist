import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/app/version_gate/app_update_required_screen.dart';
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
  bool _isDialogOpen = false;

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

  Future<void> _check() async {
    if (!mounted) {
      return;
    }
    await ref.read(appUpdateProvider.notifier).check();
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
        context == null) {
      return;
    }
    _recommendationShown = true;
    _isDialogOpen = true;

    final l10n = context.l10n;
    final url = decision.updateUrl;
    final description = switch ((url, ref.read(appUpdatePlatformProvider))) {
      (null, 'ios') => l10n.updateAvailableNoLinkIosMessage,
      (null, 'android') => l10n.updateAvailableNoLinkAndroidMessage,
      _ => l10n.updateAvailableMessage,
    };

    unawaited(
      showAppDialog(
        context,
        title: l10n.updateAvailableTitle,
        content: Text(
          description,
          style: AppTextStyles.small.copyWith(color: AppColors.makara),
        ),
        confirmButtonLabel: l10n.updateButton,
        cancelButtonLabel: l10n.updateLaterButton,
        onCancel: () => _isDialogOpen = false,
        // No confirm button without a store page
        onConfirm: url == null
            ? null
            : () async {
                _isDialogOpen = false;
                _openStore(url);
              },
      ).whenComplete(() => _isDialogOpen = false),
    );
  }

  void _closeDialog() {
    if (_isDialogOpen) {
      _isDialogOpen = false;
      widget.navigatorKey.currentState?.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateProvider, (_, decision) {
      switch (decision.status) {
        case AppUpdateStatus.required:
          // The wall replaces the app, Navigator and dialog route included:
          // nothing to pop.
          _isDialogOpen = false;
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
