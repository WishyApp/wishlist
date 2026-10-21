import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wishlist/app/config/deeplink_config.dart';

/// Opens the screen matching the links the app receives (wishy:// links and
/// https://wishy-app.fr links).
///
/// Flutter's own deep linking is disabled (flutter_deeplinking_enabled /
/// FlutterDeepLinkingEnabled set to false) as app_links requires: this class
/// is the only one to navigate on a link. Supabase listens to the same links
/// on its side, only to read the auth parameters.
class DeepLinkNavigator {
  DeepLinkNavigator({
    required Future<Uri?> Function() getInitialLink,
    required Stream<Uri> links,
    required void Function(String location) navigate,
  })  : _getInitialLink = getInitialLink,
        _links = links,
        _navigate = navigate;

  final Future<Uri?> Function() _getInitialLink;
  final Stream<Uri> _links;
  final void Function(String location) _navigate;
  StreamSubscription<Uri>? _subscription;

  /// The link stream only replays the launch link to its first listener,
  /// which is Supabase: the launch link is read on its own. If the stream
  /// still delivers it, opening the same location twice is harmless.
  Future<void> start() async {
    if (_subscription != null) {
      return;
    }

    _subscription = _links.listen(
      _open,
      onError: (Object error) {
        debugPrint('Could not receive a deep link: $error');
      },
    );

    try {
      final initialLink = await _getInitialLink();
      if (initialLink != null) {
        _open(initialLink);
      }
    } catch (error) {
      debugPrint('Could not read the initial deep link: $error');
    }
  }

  void _open(Uri uri) {
    final location = DeeplinkConfig.locationFromUri(uri);
    if (location != null) {
      _navigate(location);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
