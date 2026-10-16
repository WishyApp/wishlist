import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
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
  final Map<String, StreamController<dynamic>> _controllers = {};

  /// Chaque controller est un [BehaviorSubject] : un abonné qui arrive après le
  /// premier chargement reçoit tout de suite la dernière valeur (ou erreur),
  /// puis les suivantes. `onCancel` se déclenche quand le dernier abonné part.
  ///
  /// Les controllers de clés différentes n'ont pas le même type d'événement :
  /// la clé détermine le type attendu.
  StreamController<T>? _existingController<T>(String key) =>
      _controllers[key] as StreamController<T>?;

  /// Abonne un channel aux lignes de `friendships` où [userId] figure dans
  /// l'une des [columns] (un filtre `eq` par colonne, donc un listener par
  /// colonne).
  ///
  /// Les DELETE sont filtrés comme les autres événements, car la table est en
  /// `REPLICA IDENTITY FULL` : l'ancienne ligne contient toutes ses colonnes.
  /// La RLS n'est pas appliquée aux DELETE, mais le filtre les limite aux
  /// lignes qui concernent l'utilisateur. Le payload ne sert que de
  /// déclencheur de rechargement.
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
    return channel.subscribe();
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

    late final StreamController<FriendshipIds> controller;
    controller = BehaviorSubject<FriendshipIds>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    _loadAllFriendships(currentUserId, controller);

    final channel = _subscribeToFriendships(
      channelName: 'friendships_all_$currentUserId',
      userId: currentUserId,
      columns: _bothUserColumns,
      onChange: () => _loadAllFriendships(currentUserId, controller),
    );

    _channels[key] = channel;

    return controller.stream;
  }

  Future<void> _loadAllFriendships(
    String userId,
    StreamController<FriendshipIds> controller,
  ) async {
    try {
      final results = await Future.wait([
        _friendshipRepository.getFriendsIds(userId),
        _friendshipRepository.getCurrentUserPendingFriendsIds(),
        _friendshipRepository.getCurrentUserRequestedFriendsIds(),
      ]);

      if (!controller.isClosed) {
        controller.add(
          FriendshipIds(
            friendsIds: results[0],
            pendingIds: results[1],
            requestedIds: results[2],
          ),
        );
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  @override
  Stream<ISet<String>> watchFriendsIds(String userId) {
    final key = 'friends_$userId';

    // ignore: close_sinks - Le controller est déjà créé et sera fermé dans _cleanupStream
    final existingController = _existingController<ISet<String>>(key);
    if (existingController != null) {
      return existingController.stream;
    }

    late final StreamController<ISet<String>> controller;
    controller = BehaviorSubject<ISet<String>>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    _loadInitialFriends(userId, controller);

    final channel = _subscribeToFriendships(
      channelName: 'friendships_$userId',
      userId: userId,
      columns: _bothUserColumns,
      onChange: () => _handleFriendshipChange(userId, controller),
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

    late final StreamController<ISet<String>> controller;
    controller = BehaviorSubject<ISet<String>>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    _loadInitialPending(currentUserId, controller);

    // Les demandes envoyées par l'utilisateur : il en est le requester.
    final channel = _subscribeToFriendships(
      channelName: 'friendships_pending_$currentUserId',
      userId: currentUserId,
      columns: const ['requester_id'],
      onChange: () => _handlePendingChange(currentUserId, controller),
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

    late final StreamController<ISet<String>> controller;
    controller = BehaviorSubject<ISet<String>>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    _loadInitialRequested(currentUserId, controller);

    // Les demandes reçues par l'utilisateur : il en est le receiver.
    final channel = _subscribeToFriendships(
      channelName: 'friendships_requested_$currentUserId',
      userId: currentUserId,
      columns: const ['receiver_id'],
      onChange: () => _handleRequestedChange(currentUserId, controller),
    );

    _channels[key] = channel;

    return controller.stream;
  }

  Future<void> _loadInitialFriends(
    String userId,
    StreamController<ISet<String>> controller,
  ) async {
    try {
      final friendsIds = await _friendshipRepository.getFriendsIds(userId);
      if (!controller.isClosed) {
        controller.add(friendsIds);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  Future<void> _loadInitialPending(
    String userId,
    StreamController<ISet<String>> controller,
  ) async {
    try {
      final pendingIds =
          await _friendshipRepository.getCurrentUserPendingFriendsIds();
      if (!controller.isClosed) {
        controller.add(pendingIds);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  Future<void> _loadInitialRequested(
    String userId,
    StreamController<ISet<String>> controller,
  ) async {
    try {
      final requestedIds =
          await _friendshipRepository.getCurrentUserRequestedFriendsIds();
      if (!controller.isClosed) {
        controller.add(requestedIds);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  Future<void> _handleFriendshipChange(
    String userId,
    StreamController<ISet<String>> controller,
  ) async {
    try {
      final friendsIds = await _friendshipRepository.getFriendsIds(userId);

      if (!controller.isClosed) {
        controller.add(friendsIds);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  Future<void> _handlePendingChange(
    String userId,
    StreamController<ISet<String>> controller,
  ) async {
    try {
      final pendingIds =
          await _friendshipRepository.getCurrentUserPendingFriendsIds();

      if (!controller.isClosed) {
        controller.add(pendingIds);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  Future<void> _handleRequestedChange(
    String userId,
    StreamController<ISet<String>> controller,
  ) async {
    try {
      final requestedIds =
          await _friendshipRepository.getCurrentUserRequestedFriendsIds();

      if (!controller.isClosed) {
        controller.add(requestedIds);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  void _cleanupStream(String key, StreamController<dynamic> controller) {
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
