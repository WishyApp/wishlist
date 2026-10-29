import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/keyed_realtime_streams.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_stream_repository.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';
import 'package:wishlist/shared/utils/first_event_timeout.dart';

class SupabaseUserCompletedWishStreamRepository
    implements UserCompletedWishStreamRepository {
  SupabaseUserCompletedWishStreamRepository(
    this._client,
    this._repository,
  );

  final SupabaseClient _client;
  final UserCompletedWishRepository _repository;
  static const _tableName = 'user_completed_wishs';

  late final _streams = KeyedRealtimeStreams(
    logTag: 'completed wishes',
    isSocketConnected: () => _client.realtime.isConnected,
  );

  @override
  Stream<IList<CompletedWishWithDetails>> watchCompletedWishesByUser(
    String userId,
  ) {
    final key = 'completed_wishes_$userId';

    return _streams.watch<IList<CompletedWishWithDetails>>(
      key,
      // Le délai est sur le chargement partagé, pas sur le stream de chaque
      // provider : un délai posé en aval n'atteint jamais le subject, qui
      // resterait sans valeur ni erreur et ne relancerait aucun chargement sur
      // « Réessayer » tant qu'un autre écran l'écoute. Ici le
      // TimeoutException entre dans le subject et le retry fonctionne pour
      // tous les abonnés.
      load: () => _repository
          .getCompletedWishesByUser(userId)
          .timeout(firstEventTimeLimit),
      channelBuilder: (reload) => _client
          .channel('completed_wishes_$userId')
          // Changements sur user_completed_wishs filtrés par user_id
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _tableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) => reload(),
          )
          // Si un wish complété est modifié/supprimé
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wishs',
            callback: (payload) => reload(),
          )
          // Si la wishlist d'origine est renommée ou supprimée
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wishlists',
            callback: (payload) => reload(),
          )
          // Si le pseudo/avatar du propriétaire change
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            callback: (payload) => reload(),
          ),
    );
  }

  @override
  Stream<ReceivedWishesSummary> watchReceivedWishesSummary(String userId) {
    final key = 'received_wishes_summary_$userId';

    return _streams.watch<ReceivedWishesSummary>(
      key,
      // Timeout on the shared load, for the same reason as above
      load: () => _repository
          .getReceivedWishesSummary(userId)
          .timeout(firstEventTimeLimit),
      // Only the rows of the user: a change of anybody's wish, wishlist or
      // profile does not matter to a count and a date
      channelBuilder: (reload) => _client.channel(key).onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _tableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) => reload(),
          ),
    );
  }

  @override
  void dispose() {
    // L'interface est synchrone : le nettoyage se termine en arrière-plan.
    unawaited(_streams.dispose());
  }
}
