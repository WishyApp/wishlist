import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/keyed_realtime_streams.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_stream_repository.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';

class SupabaseWishStreamRepository implements WishStreamRepository {
  SupabaseWishStreamRepository(
    this._client,
    this._wishRepository,
  );

  final SupabaseClient _client;
  final WishRepository _wishRepository;
  static const _wishsTableName = 'wishs';
  static const _wishTakenByUserTableName = 'wish_taken_by_user';
  static const _userCompletedWishsTableName = 'user_completed_wishs';
  static const _wishlistsTableName = 'wishlists';
  static const _canOwnerSeeTakenWishColumn = 'can_owner_see_taken_wish';

  /// Un wish supprimé (ou masqué par la RLS) n'est pas une erreur passagère :
  /// on l'émet même après une valeur, sinon il resterait affiché.
  late final _streams = KeyedRealtimeStreams(
    logTag: 'wishs',
    shouldEmitErrorAfterValue: _isNotFound,
    isSocketConnected: () => _client.realtime.isConnected,
  );

  @override
  Stream<IList<Wish>> watchWishsFromWishlist(int wishlistId) {
    final key = 'wishlist_$wishlistId';

    Future<IList<Wish>> fetch() =>
        _wishRepository.getWishsFromWishlist(wishlistId);

    return _streams.watch<IList<Wish>>(
      key,
      load: fetch,
      channelBuilder: (reload) => _client
          .channel('wishs_wishlist_$wishlistId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _wishsTableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'wishlist_id',
              value: wishlistId,
            ),
            callback: (payload) => reload(),
          )
          // Écouter aussi les UPDATE sans filtre pour détecter les wishs
          // qui sont déplacés vers/depuis cette wishlist
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: _wishsTableName,
            callback: (payload) {
              // Recharger uniquement si le wish concerné nous intéresse
              final oldRecord = payload.oldRecord;
              final newRecord = payload.newRecord;
              final oldWishlistId = oldRecord['wishlist_id'] as int?;
              final newWishlistId = newRecord['wishlist_id'] as int?;

              // Si le wish est déplacé depuis ou vers cette wishlist
              if (oldWishlistId == wishlistId || newWishlistId == wishlistId) {
                reload();
              }
            },
          )
          // Écouter aussi les changements sur wish_taken_by_user
          // pour mettre à jour les réservations en temps réel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wish_taken_by_user',
            callback: (payload) {
              // Quand une réservation change, recharger tous les wishs
              // pour récupérer les données à jour avec le JOIN
              reload();
            },
          )
          // Écouter aussi la wishlist elle-même : quand
          // can_owner_see_taken_wish change, les réservations lues par le
          // propriétaire changent (RLS) sans qu'aucune ligne de wishs ou de
          // wish_taken_by_user ne bouge. wishlists est en REPLICA IDENTITY
          // FULL, l'ancienne valeur est donc fournie ; à défaut on recharge.
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: _wishlistsTableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: wishlistId,
            ),
            callback: (payload) {
              final oldValue = payload.oldRecord[_canOwnerSeeTakenWishColumn];
              final newValue = payload.newRecord[_canOwnerSeeTakenWishColumn];
              if (oldValue == null || oldValue != newValue) {
                reload();
              }
            },
          ),
    );
  }

  @override
  Stream<Wish> watchWishById(int wishId) {
    final key = 'wish_$wishId';

    Future<Wish> fetch() => _wishRepository.getWishById(wishId);

    return _streams.watch<Wish>(
      key,
      load: fetch,
      channelBuilder: (reload) => _client
          .channel('wish_$wishId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _wishsTableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: wishId,
            ),
            callback: (payload) => reload(),
          )
          // Écouter aussi les changements sur wish_taken_by_user
          // pour mettre à jour les réservations en temps réel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wish_taken_by_user',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'wish_id',
              value: wishId,
            ),
            callback: (payload) {
              // Quand une réservation change, recharger le wish
              // pour récupérer les données à jour avec le JOIN
              reload();
            },
          ),
    );
  }

  @override
  Stream<IList<BookedWishWithDetails>> watchBookedWishesByUser(String userId) {
    final key = 'booked_wishes_$userId';

    Future<IList<BookedWishWithDetails>> fetch() =>
        _wishRepository.getBookedWishesByUser(userId);

    return _streams.watch<IList<BookedWishWithDetails>>(
      key,
      load: fetch,
      // Écouter les changements sur wish_taken_by_user (réservations)
      channelBuilder: (reload) => _client
          .channel('booked_wishes_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _wishTakenByUserTableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) => reload(),
          )
          // Écouter les réceptions (un wish réservé marqué comme reçu par
          // son propriétaire passe dans les offerts)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _userCompletedWishsTableName,
            callback: (payload) => reload(),
          )
          // Écouter les changements sur la table wishs
          // (si un wish réservé est modifié/supprimé)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _wishsTableName,
            callback: (payload) => reload(),
          )
          // Écouter les changements sur wishlists (si nom change)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wishlists',
            callback: (payload) => reload(),
          )
          // Écouter les changements sur profiles (si pseudo/avatar change)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            callback: (payload) => reload(),
          ),
    );
  }

  static bool _isNotFound(Object error) {
    if (error is! AppException) {
      return false;
    }
    final cause = error.cause;
    return cause is PostgrestException && cause.code == 'PGRST116';
  }

  @override
  Future<void> dispose() => _streams.dispose();
}
