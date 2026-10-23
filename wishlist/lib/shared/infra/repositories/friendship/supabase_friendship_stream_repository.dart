import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/keyed_realtime_streams.dart';
import 'package:wishlist/shared/infra/non_null_extensions/go_true_client_non_null_getter_user_extension.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_repository.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_stream_repository.dart';

class SupabaseFriendshipStreamRepository implements FriendshipStreamRepository {
  SupabaseFriendshipStreamRepository(
    this._client,
    this._friendshipRepository,
  );

  final SupabaseClient _client;
  final FriendshipRepository _friendshipRepository;
  static const _friendshipsTableName = 'friendships';

  static const _bothUserColumns = ['requester_id', 'receiver_id'];

  final _streams = KeyedRealtimeStreams(logTag: 'friendships');

  /// Construit, sans l'abonner, un channel aux lignes de `friendships` où
  /// [userId] figure dans l'une des [columns] (un filtre `eq` par colonne, donc
  /// un listener par colonne).
  ///
  /// Un changement validé entre la première requête et l'abonnement du channel
  /// n'est jamais livré en événement : [KeyedRealtimeStreams] recharge une fois
  /// le channel abonné (et à chaque reconnexion).
  ///
  /// Le filtre réduit le trafic, ce n'est pas une barrière d'accès : le client
  /// en choisit la valeur, et la RLS n'est pas appliquée aux DELETE.
  ///
  /// Les DELETE sont filtrés comme les autres événements. Realtime évalue le
  /// filtre sur l'ancienne ligne complète, que Postgres journalise parce que
  /// `friendships` est en `REPLICA IDENTITY FULL` (vérifié par
  /// `supabase-tests/friendships_realtime.sql`). Avec la RLS, le payload reçu
  /// ne contient ensuite que la clé primaire dans `oldRecord` : il ne sert que
  /// de déclencheur de rechargement, ne pas y lire `requester_id`.
  RealtimeChannel _subscribeToFriendships({
    required String channelName,
    required String userId,
    required List<String> columns,
    required void Function() onChange,
  }) {
    var channel = _client.channel(channelName);
    for (final column in columns) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: _friendshipsTableName,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: column,
          value: userId,
        ),
        callback: (payload) => onChange(),
      );
    }
    return channel;
  }

  @override
  Stream<FriendshipIds> watchCurrentUserAllFriendships() {
    final currentUserId = _client.auth.currentUserNonNull.id;
    final key = 'all_friendships_$currentUserId';

    return _streams.watch<FriendshipIds>(
      key,
      load: () => _fetchAllFriendships(currentUserId),
      skipEqual: true,
      channelBuilder: (reload) => _subscribeToFriendships(
        channelName: 'friendships_all_$currentUserId',
        userId: currentUserId,
        columns: _bothUserColumns,
        onChange: reload,
      ),
    );
  }

  Future<FriendshipIds> _fetchAllFriendships(String userId) async {
    final results = await Future.wait([
      _friendshipRepository.getFriendsIds(userId),
      _friendshipRepository.getCurrentUserPendingFriendsIds(),
      _friendshipRepository.getCurrentUserRequestedFriendsIds(),
    ]);

    return FriendshipIds(
      friendsIds: results[0],
      pendingIds: results[1],
      requestedIds: results[2],
    );
  }

  @override
  Stream<ISet<String>> watchFriendsIds(String userId) {
    final key = 'friends_$userId';

    return _streams.watch<ISet<String>>(
      key,
      load: () => _friendshipRepository.getFriendsIds(userId),
      skipEqual: true,
      channelBuilder: (reload) => _subscribeToFriendships(
        channelName: 'friendships_$userId',
        userId: userId,
        columns: _bothUserColumns,
        onChange: reload,
      ),
    );
  }

  @override
  Stream<ISet<String>> watchCurrentUserPendingFriendsIds() {
    final currentUserId = _client.auth.currentUserNonNull.id;
    final key = 'pending_$currentUserId';

    return _streams.watch<ISet<String>>(
      key,
      load: _friendshipRepository.getCurrentUserPendingFriendsIds,
      skipEqual: true,
      // Les demandes envoyées par l'utilisateur : il en est le requester.
      channelBuilder: (reload) => _subscribeToFriendships(
        channelName: 'friendships_pending_$currentUserId',
        userId: currentUserId,
        columns: const ['requester_id'],
        onChange: reload,
      ),
    );
  }

  @override
  Stream<ISet<String>> watchCurrentUserRequestedFriendsIds() {
    final currentUserId = _client.auth.currentUserNonNull.id;
    final key = 'requested_$currentUserId';

    return _streams.watch<ISet<String>>(
      key,
      load: _friendshipRepository.getCurrentUserRequestedFriendsIds,
      skipEqual: true,
      // Les demandes reçues par l'utilisateur : il en est le receiver.
      channelBuilder: (reload) => _subscribeToFriendships(
        channelName: 'friendships_requested_$currentUserId',
        userId: currentUserId,
        columns: const ['receiver_id'],
        onChange: reload,
      ),
    );
  }

  @override
  Future<void> dispose() => _streams.dispose();
}
