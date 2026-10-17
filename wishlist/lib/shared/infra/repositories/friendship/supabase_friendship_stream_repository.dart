import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  final Map<String, RealtimeChannel> _channels = {};

  /// Chaque controller est un [BehaviorSubject] (et non un
  /// `StreamController.broadcast`, qui ne rejoue rien) : un abonné qui arrive
  /// après le premier chargement reçoit tout de suite la dernière valeur,
  /// puis les suivantes. `onCancel` se déclenche quand le dernier abonné part.
  /// Le type de la map interdit d'en créer un autre type par erreur.
  final Map<String, BehaviorSubject<dynamic>> _controllers = {};

  /// Numéro du dernier chargement lancé par clé, voir [_load].
  final Map<String, int> _loadGenerations = {};

  /// Les controllers de clés différentes n'ont pas le même type d'événement :
  /// la clé détermine le type attendu.
  BehaviorSubject<T>? _existingController<T>(String key) =>
      _controllers[key] as BehaviorSubject<T>?;

  /// Abonne un channel aux lignes de `friendships` où [userId] figure dans
  /// l'une des [columns] (un filtre `eq` par colonne, donc un listener par
  /// colonne).
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
    required void Function() onSubscribed,
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
    return channel.subscribe((status, _) {
      // Un changement validé entre la première requête et l'abonnement du
      // channel n'est jamais livré en événement : on recharge une fois abonné
      // (et à chaque reconnexion). Les autres statuts
      // ne disent rien du contenu.
      if (status == RealtimeSubscribeStatus.subscribed) {
        onSubscribed();
      }
    });
  }

  /// Charge une valeur et l'émet sur [controller].
  ///
  /// Les rechargements ne sont pas séquencés : seul le dernier lancé pour la
  /// clé compte, un résultat plus ancien qui termine après lui est ignoré
  /// (sinon, rejoué par le [BehaviorSubject], il resterait en cache).
  ///
  /// Une erreur n'est émise que tant qu'aucune valeur n'a été émise : sinon
  /// elle remplacerait la dernière bonne valeur pour les abonnés suivants.
  Future<void> _load<T>(
    String key,
    BehaviorSubject<T> controller,
    Future<T> Function() fetch,
  ) async {
    if (controller.isClosed) {
      return;
    }
    final generation = _loadGenerations[key] = (_loadGenerations[key] ?? 0) + 1;
    bool isStale() =>
        controller.isClosed || _loadGenerations[key] != generation;

    try {
      final value = await fetch();
      if (!isStale()) {
        controller.add(value);
      }
    } catch (e, st) {
      if (isStale()) {
        return;
      }
      if (controller.hasValue) {
        debugPrint('[Wishy friendships] reload failed, keeping last value: $e');
        debugPrint(st.toString());
      } else {
        controller.addError(e, st);
      }
    }
  }

  @override
  Stream<FriendshipIds> watchCurrentUserAllFriendships() {
    final currentUserId = _client.auth.currentUserNonNull.id;
    final key = 'all_friendships_$currentUserId';

    // ignore: close_sinks - Le controller est déjà créé et sera fermé dans _cleanupStream
    final existingController = _existingController<FriendshipIds>(key);
    if (existingController != null) {
      return existingController.stream;
    }

    late final BehaviorSubject<FriendshipIds> controller;
    controller = BehaviorSubject<FriendshipIds>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    void reload() =>
        _load(key, controller, () => _fetchAllFriendships(currentUserId));
    reload();

    final channel = _subscribeToFriendships(
      channelName: 'friendships_all_$currentUserId',
      userId: currentUserId,
      columns: _bothUserColumns,
      onChange: reload,
      onSubscribed: reload,
    );

    _channels[key] = channel;

    return controller.stream;
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

    // ignore: close_sinks - Le controller est déjà créé et sera fermé dans _cleanupStream
    final existingController = _existingController<ISet<String>>(key);
    if (existingController != null) {
      return existingController.stream;
    }

    late final BehaviorSubject<ISet<String>> controller;
    controller = BehaviorSubject<ISet<String>>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    void reload() => _load(
          key,
          controller,
          () => _friendshipRepository.getFriendsIds(userId),
        );
    reload();

    final channel = _subscribeToFriendships(
      channelName: 'friendships_$userId',
      userId: userId,
      columns: _bothUserColumns,
      onChange: reload,
      onSubscribed: reload,
    );

    _channels[key] = channel;

    return controller.stream;
  }

  @override
  Stream<ISet<String>> watchCurrentUserFriendsIds() {
    final currentUserId = _client.auth.currentUserNonNull.id;
    return watchFriendsIds(currentUserId);
  }

  @override
  Stream<ISet<String>> watchCurrentUserPendingFriendsIds() {
    final currentUserId = _client.auth.currentUserNonNull.id;
    final key = 'pending_$currentUserId';

    // ignore: close_sinks - Le controller est déjà créé et sera fermé dans _cleanupStream
    final existingController = _existingController<ISet<String>>(key);
    if (existingController != null) {
      return existingController.stream;
    }

    late final BehaviorSubject<ISet<String>> controller;
    controller = BehaviorSubject<ISet<String>>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    void reload() => _load(
          key,
          controller,
          _friendshipRepository.getCurrentUserPendingFriendsIds,
        );
    reload();

    // Les demandes envoyées par l'utilisateur : il en est le requester.
    final channel = _subscribeToFriendships(
      channelName: 'friendships_pending_$currentUserId',
      userId: currentUserId,
      columns: const ['requester_id'],
      onChange: reload,
      onSubscribed: reload,
    );

    _channels[key] = channel;

    return controller.stream;
  }

  @override
  Stream<ISet<String>> watchCurrentUserRequestedFriendsIds() {
    final currentUserId = _client.auth.currentUserNonNull.id;
    final key = 'requested_$currentUserId';

    // ignore: close_sinks - Le controller est déjà créé et sera fermé dans _cleanupStream
    final existingController = _existingController<ISet<String>>(key);
    if (existingController != null) {
      return existingController.stream;
    }

    late final BehaviorSubject<ISet<String>> controller;
    controller = BehaviorSubject<ISet<String>>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    void reload() => _load(
          key,
          controller,
          _friendshipRepository.getCurrentUserRequestedFriendsIds,
        );
    reload();

    // Les demandes reçues par l'utilisateur : il en est le receiver.
    final channel = _subscribeToFriendships(
      channelName: 'friendships_requested_$currentUserId',
      userId: currentUserId,
      columns: const ['receiver_id'],
      onChange: reload,
      onSubscribed: reload,
    );

    _channels[key] = channel;

    return controller.stream;
  }

  void _cleanupStream(String key, BehaviorSubject<dynamic> controller) {
    // Ignore un cancel tardif d'un ancien controller (ex: pendant dispose) si
    // la clé a été reprise par un nouveau.
    if (!identical(_controllers[key], controller)) {
      return;
    }
    _channels[key]?.unsubscribe();
    _channels.remove(key);
    controller.close();
    _controllers.remove(key);
  }

  @override
  Future<void> dispose() async {
    // Un cancel pendant les await déclenche onCancel -> _cleanupStream, qui
    // modifie _channels et _controllers : on itère donc sur des copies.
    final channels = _channels.values.toList();
    _channels.clear();
    for (final channel in channels) {
      await channel.unsubscribe();
    }

    final controllers = _controllers.values.toList();
    _controllers.clear();
    for (final controller in controllers) {
      await controller.close();
    }
  }
}
