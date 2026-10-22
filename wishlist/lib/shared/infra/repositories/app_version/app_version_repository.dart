import 'package:wishlist/shared/models/app_version_policy.dart';

abstract class AppVersionRepository {
  /// Policy of [platform] (`ios` or `android`), or null if the server has
  /// none for it.
  Future<AppVersionPolicy?> getPolicy(String platform);
}
