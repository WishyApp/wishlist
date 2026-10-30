import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository.dart';
import 'package:wishlist/shared/infra/utils/execute_safely.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

class SupabaseYearRecapRepository implements YearRecapRepository {
  SupabaseYearRecapRepository(this._client);

  final SupabaseClient _client;
  static const _illustrationsBucket = 'year-recap-illustrations';

  @override
  Future<YearRecapData> getMyYearRecap(int year) async {
    return executeSafely(
      () async {
        final response = await _client.rpc<dynamic>(
          'get_my_year_recap',
          params: {'p_year': year},
        );
        return YearRecapData.fromJson(response as Map<String, dynamic>);
      },
      errorMessage: 'Failed to load the year recap',
    );
  }

  @override
  String illustrationUrl(String path) {
    return _client.storage.from(_illustrationsBucket).getPublicUrl(path);
  }
}
