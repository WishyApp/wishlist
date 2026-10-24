import 'package:wishlist/app/config/deeplink_config.dart';

/// The internal path (with its query) to open for a `redirectTo` value, or null
/// when it is not safe: a plain path, or one of our own wishy:// deep links
/// reduced to its path. Anything else (other schemes or hosts, `//host/x`) is
/// dropped.
String? sanitizeRedirectTarget(String? target) {
  if (target == null || target.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(target);
  if (uri == null) {
    return null;
  }

  if (!uri.hasScheme && !uri.hasAuthority) {
    if (!target.startsWith('/')) {
      return null;
    }

    return target;
  }

  final isWishyDeepLink = DeeplinkConfig.isValidDeeplink(uri);

  if (!isWishyDeepLink || !uri.path.startsWith('/')) {
    return null;
  }

  return Uri(
    path: uri.path,
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  ).toString();
}

/// [baseLocation] carrying [redirectTo] in the `redirectTo` query parameter
/// (a typed route parameter would be named `redirect-to`), or [baseLocation]
/// alone when [redirectTo] is null. The value is not sanitized here.
String locationWithRedirectTo(String baseLocation, String? redirectTo) {
  return Uri(
    path: baseLocation,
    queryParameters: redirectTo == null ? null : {'redirectTo': redirectTo},
  ).toString();
}
