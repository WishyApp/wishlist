import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/keyed_realtime_streams.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_repository.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_stream_repository.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

class SupabaseWishlistStreamRepository implements WishlistStreamRepository {
  SupabaseWishlistStreamRepository(
    this._client,
    this._wishlistRepository,
  );

  final SupabaseClient _client;
  final WishlistRepository _wishlistRepository;
  static const _wishlistsTableName = 'wishlists';

  final _streams = KeyedRealtimeStreams(logTag: 'wishlists');

  @override
  Stream<IList<Wishlist>> watchWishlistsByUser(String userId) {
    final key = 'user_$userId';

    Future<IList<Wishlist>> fetch() =>
        _wishlistRepository.getWishlistsByUser(userId);

    return _streams.watch<IList<Wishlist>>(
      key,
      load: fetch,
      channelBuilder: (reload) =>
          _client.channel('wishlists_user_$userId').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: _wishlistsTableName,
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'id_owner',
                  value: userId,
                ),
                callback: (payload) => reload(),
              ),
    );
  }

  @override
  Stream<Wishlist?> watchWishlistById(int wishlistId) {
    final key = 'wishlist_$wishlistId';

    Future<Wishlist?> fetch() =>
        _wishlistRepository.findWishlistById(wishlistId);

    return _streams.watch<Wishlist?>(
      key,
      load: fetch,
      channelBuilder: (reload) =>
          _client.channel('wishlist_$wishlistId').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: _wishlistsTableName,
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'id',
                  value: wishlistId,
                ),
                callback: (payload) => reload(
                  () async {
                    // L'archivage d'une wishlist arrive en UPDATE avec
                    // deleted_at renseigné
                    if (payload.eventType == PostgresChangeEvent.delete ||
                        payload.newRecord['deleted_at'] != null) {
                      return null;
                    }
                    return fetch();
                  },
                ),
              ),
    );
  }

  @override
  Stream<IList<Wishlist>> watchPublicWishlistsByUser(String userId) {
    final key = 'user_public_$userId';

    Future<IList<Wishlist>> fetch() =>
        _wishlistRepository.getPublicWishlistsByUser(userId);

    // Note: Supabase Realtime ne supporte qu'un seul filtre
    // PostgresChangeFilter : on filtre par id_owner, et is_public est appliqué
    // par la requête à chaque rechargement.
    return _streams.watch<IList<Wishlist>>(
      key,
      load: fetch,
      channelBuilder: (reload) =>
          _client.channel('wishlists_public_user_$userId').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: _wishlistsTableName,
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'id_owner',
                  value: userId,
                ),
                callback: (payload) => reload(),
              ),
    );
  }

  @override
  Future<void> dispose() => _streams.dispose();
}
