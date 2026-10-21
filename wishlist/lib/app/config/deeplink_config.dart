import 'package:wishlist/shared/navigation/routes.dart';

abstract class DeeplinkConfig {
  /// Must match android:scheme in AndroidManifest.xml
  /// and CFBundleURLSchemes in Info.plist
  static const String scheme = 'wishy';

  /// Must match android:host in AndroidManifest.xml
  /// and CFBundleURLName in Info.plist
  static const String host = 'com.raphtang.wishy';

  /// Domain of the public links (App Links / Universal Links).
  ///
  /// Must match the https intent-filter in AndroidManifest.xml, the
  /// applinks entry in Runner.entitlements and the files served by the site
  /// (site/.well-known).
  static const String webHost = 'wishy-app.fr';

  /// First path segment of a shared wishlist link: https://wishy-app.fr/w/42.
  ///
  /// These links live on in conversations: never change the format, only add
  /// new ones.
  static const String sharedWishlistSegment = 'w';

  static final RegExp _positiveInteger = RegExp(r'^[1-9][0-9]*$');

  static Uri buildDeeplinkUri({
    required String path,
  }) {
    return Uri(
      scheme: scheme,
      host: host,
      pathSegments:
          path.split('/').where((segment) => segment.isNotEmpty).toList(),
    );
  }

  /// Public link to share a wishlist, clickable in any messaging app.
  static Uri buildWishlistShareUri({required int wishlistId}) {
    return Uri(
      scheme: 'https',
      host: webHost,
      pathSegments: [sharedWishlistSegment, '$wishlistId'],
    );
  }

  static bool isValidDeeplink(Uri uri) {
    return uri.scheme == scheme && uri.host == host;
  }

  /// Router location to open for a link received by the app, or null when the
  /// link is not one of ours.
  ///
  /// The query is dropped: the links we generate carry none apart from the
  /// auth parameters (reset password code), which Supabase reads on its own.
  static String? locationFromUri(Uri uri) {
    if (isValidDeeplink(uri)) {
      return uri.path.isEmpty ? HomeRoute().location : uri.path;
    }

    if (uri.scheme == 'https' && uri.host == webHost) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length == 2 &&
          segments.first == sharedWishlistSegment &&
          _positiveInteger.hasMatch(segments.last)) {
        final wishlistId = int.tryParse(segments.last);
        if (wishlistId != null) {
          return WishlistRoute(wishlistId: wishlistId).location;
        }
      }
    }

    return null;
  }
}
