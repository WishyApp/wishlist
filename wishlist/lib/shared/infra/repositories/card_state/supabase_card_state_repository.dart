import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository.dart';
import 'package:wishlist/shared/infra/utils/execute_safely.dart';
import 'package:wishlist/shared/models/card_state.dart';

class SupabaseCardStateRepository implements CardStateRepository {
  SupabaseCardStateRepository(this._client);
  final SupabaseClient _client;

  static const _keysPerRequest = 50;
  static const _columns =
      'card_key, shown_count, last_shown_at, dismissed_at, snoozed_until';

  /// RLS only returns the rows of the current user. The keys go by batches so
  /// that the URL of a request stays short.
  @override
  Future<Map<String, CardState>> getStates(Iterable<String> cardKeys) async {
    final keys = cardKeys.toList();
    if (keys.isEmpty) {
      return const {};
    }
    return executeSafely(
      () async {
        final states = <String, CardState>{};
        for (var start = 0; start < keys.length; start += _keysPerRequest) {
          final batch = keys.skip(start).take(_keysPerRequest).toList();
          final rows = await _client
              .from('user_card_states')
              .select(_columns)
              .inFilter('card_key', batch);

          // One malformed row must not hide the other card states.
          for (final row in rows) {
            try {
              final state = CardState.fromRow(row);
              states[state.cardKey] = state;
            } on Object {
              debugPrint('[Wishy card states] skipped a malformed row: $row');
            }
          }
        }
        return states;
      },
      errorMessage: 'Failed to load the card states',
    );
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
