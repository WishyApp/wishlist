import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository.dart';
import 'package:wishlist/shared/infra/utils/execute_safely.dart';
import 'package:wishlist/shared/models/card_state.dart';

class SupabaseCardStateRepository implements CardStateRepository {
  SupabaseCardStateRepository(this._client);
  final SupabaseClient _client;

  /// RLS only returns the rows of the current user.
  @override
  Future<Map<String, CardState>> getStates(Iterable<String> cardKeys) async {
    final keys = cardKeys.toList();
    if (keys.isEmpty) {
      return const {};
    }
    final rows = await executeSafely(
      () =>
          _client.from('user_card_states').select().inFilter('card_key', keys),
      errorMessage: 'Failed to load the card states',
    );
    final states = rows.map(CardState.fromRow);
    return {for (final state in states) state.cardKey: state};
  }

  @override
  Future<void> recordShown(String cardKey) {
    return executeSafely(
      () => _client.rpc<void>(
        'record_card_shown',
        params: {'p_card_key': cardKey},
      ),
      errorMessage: 'Failed to record a shown card',
    );
  }

  @override
  Future<void> dismiss(String cardKey, {DateTime? snoozeUntil}) {
    return executeSafely(
      () => _client.rpc<void>(
        'dismiss_card',
        params: {
          'p_card_key': cardKey,
          'p_snooze_until': snoozeUntil?.toUtc().toIso8601String(),
        },
      ),
      errorMessage: 'Failed to dismiss a card',
    );
  }
}
