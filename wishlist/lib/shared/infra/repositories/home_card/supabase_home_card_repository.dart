import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/home_card/home_card_repository.dart';
import 'package:wishlist/shared/infra/utils/execute_safely.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

class SupabaseHomeCardRepository implements HomeCardRepository {
  SupabaseHomeCardRepository(this._client);
  final SupabaseClient _client;

  /// RLS already hides disabled rows and editorial cards outside their window.
  @override
  Future<List<HomeCardDefinition>> getActiveCards() async {
    final rows = await executeSafely(
      () => _client.from('home_cards').select().order('priority'),
      errorMessage: 'Failed to load the home cards',
    );
    return rows.map(HomeCardDefinition.fromRow).toList();
  }
}
