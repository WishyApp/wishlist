import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/keyed_realtime_streams.dart';
import 'package:wishlist/shared/infra/repositories/wish_taken_by_user/wish_taken_by_user_stream_repository.dart';
import 'package:wishlist/shared/models/wish_taken_by_user/wish_taken_by_user.dart';

class SupabaseWishTakenByUserStreamRepository
    implements WishTakenByUserStreamRepository {
  SupabaseWishTakenByUserStreamRepository(this._client);

  final SupabaseClient _client;
  static const _tableName = 'wish_taken_by_user';

  late final _streams = KeyedRealtimeStreams(
    logTag: 'wish taken by user',
    isSocketConnected: () => _client.realtime.isConnected,
  );

  @override
  Stream<IList<WishTakenByUser>> watchTakenByUsersForWish(int wishId) =>
      _watchBy('wish_id', wishId, 'wish_$wishId');

  @override
  Stream<IList<WishTakenByUser>> watchTakenByUser(String userId) =>
      _watchBy('user_id', userId, 'user_$userId');

  /// Flux des réservations dont [column] vaut [value] ; [key] identifie le flux
  /// et nomme le channel.
  Stream<IList<WishTakenByUser>> _watchBy(
    String column,
    Object value,
    String key,
  ) {
    Future<IList<WishTakenByUser>> fetch() async {
      final response = await _client
          .from(_tableName)
          .select()
          .eq(column, value)
          .order('created_at');

      return (response as List)
          .map((json) => WishTakenByUser.fromJson(json as Map<String, dynamic>))
          .toIList();
    }

    return _streams.watch<IList<WishTakenByUser>>(
      key,
      load: fetch,
      channelBuilder: (reload) =>
          _client.channel('wish_taken_by_user_$key').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: _tableName,
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: column,
                  value: value,
                ),
                // À chaque changement, recharger toutes les données
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
