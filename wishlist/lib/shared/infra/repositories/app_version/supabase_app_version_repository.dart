import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository.dart';
import 'package:wishlist/shared/models/app_version_policy.dart';

class SupabaseAppVersionRepository implements AppVersionRepository {
  SupabaseAppVersionRepository(this._client);
  final SupabaseClient _client;

  /// `get_app_version_policy` is callable before sign in (anon).
  @override
  Future<AppVersionPolicy?> getPolicy(String platform) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_app_version_policy',
      params: {'p_platform': platform},
    );
    if (rows.isEmpty) {
      return null;
    }
    return AppVersionPolicy.fromRow(rows.first as Map<String, dynamic>);
  }
}
