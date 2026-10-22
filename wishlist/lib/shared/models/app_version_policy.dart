import 'package:flutter/foundation.dart';

/// Minimum and recommended app versions of a platform, as set on the server
/// (table `app_versions`).
@immutable
class AppVersionPolicy {
  const AppVersionPolicy({
    required this.minVersion,
    required this.recommendedVersion,
    this.updateUrl,
  });

  /// One row of `get_app_version_policy`. Throws if a column is missing or
  /// has the wrong type: the caller treats any failure as "let the user in".
  factory AppVersionPolicy.fromRow(Map<String, dynamic> row) {
    return AppVersionPolicy(
      minVersion: row['min_version'] as String,
      recommendedVersion: row['recommended_version'] as String,
      updateUrl: row['update_url'] as String?,
    );
  }

  final String minVersion;
  final String recommendedVersion;

  /// Store page to open. Null while the store links are not public.
  final String? updateUrl;
}
