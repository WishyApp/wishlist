import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_repository.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_stream_repository.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/utils/skip_replayed_error.dart';

class SupabaseWishlistStreamRepository implements WishlistStreamRepository {
  SupabaseWishlistStreamRepository(
    this._client,
    this._wishlistRepository,
  );

  final SupabaseClient _client;
  final WishlistRepository _wishlistRepository;
  static const _wishlistsTableName = 'wishlists';

  final Map<String, RealtimeChannel> _channels = {};

  /// Chaque controller est un [BehaviorSubject] (et non un
  /// `StreamController.broadcast`, qui ne rejoue rien) : un abonné qui arrive
  /// après le premier chargement (ex: un second provider sur la même clé)
  /// reçoit tout de suite la dernière valeur, puis les suivantes.
  /// `onCancel` se déclenche quand le dernier abonné part.
  final Map<String, BehaviorSubject<dynamic>> _controllers = {};

  /// Numéro du dernier chargement lancé par clé, voir [_loadData].
  final Map<String, int> _loadGenerations = {};

  /// Numéro du dernier chargement émis par clé, voir [_loadData].
  final Map<String, int> _emittedGenerations = {};

  @override
  Stream<IList<Wishlist>> watchWishlistsByUser(String userId) {
    final key = 'user_$userId';

    Future<IList<Wishlist>> fetch() =>
        _wishlistRepository.getWishlistsByUser(userId);

    // ignore: close_sinks - fermé dans _cleanupStream
    final existingStream = _existingStream<IList<Wishlist>>(key, fetch);
    if (existingStream != null) {
      return existingStream;
    }

    final controller = _createController<IList<Wishlist>>(key);

    _loadData(key, controller, fetch);

    final channel = _client
        .channel('wishlists_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _wishlistsTableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_owner',
            value: userId,
          ),
          callback: (payload) => _loadData(key, controller, fetch),
        )
        .subscribe();

    _channels[key] = channel;

    return controller.stream;
  }

  @override
  Stream<Wishlist?> watchWishlistById(int wishlistId) {
    final key = 'wishlist_$wishlistId';

    Future<Wishlist?> fetch() =>
        _wishlistRepository.findWishlistById(wishlistId);

    // ignore: close_sinks - fermé dans _cleanupStream
    final existingStream = _existingStream<Wishlist?>(key, fetch);
    if (existingStream != null) {
      return existingStream;
    }

    final controller = _createController<Wishlist?>(key);

    _loadData(key, controller, fetch);

    final channel = _client
        .channel('wishlist_$wishlistId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _wishlistsTableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: wishlistId,
          ),
          callback: (payload) => _loadData(
            key,
            controller,
            () async {
              // L'archivage d'une wishlist arrive en UPDATE avec deleted_at
              // renseigné
              if (payload.eventType == PostgresChangeEvent.delete ||
                  payload.newRecord['deleted_at'] != null) {
                return null;
              }
              return fetch();
            },
          ),
        )
        .subscribe();

    _channels[key] = channel;

    return controller.stream;
  }

  @override
  Stream<IList<Wishlist>> watchPublicWishlistsByUser(String userId) {
    final key = 'user_public_$userId';

    Future<IList<Wishlist>> fetch() =>
        _wishlistRepository.getPublicWishlistsByUser(userId);

    // ignore: close_sinks - fermé dans _cleanupStream
    final existingStream = _existingStream<IList<Wishlist>>(key, fetch);
    if (existingStream != null) {
      return existingStream;
    }

    final controller = _createController<IList<Wishlist>>(key);

    _loadData(key, controller, fetch);

    // Créer le channel Realtime
    // Note: Supabase Realtime ne supporte qu'un seul filtre
    // PostgresChangeFilter
    // On filtre par id_owner et on vérifie is_public dans le payload
    final channel = _client
        .channel('wishlists_public_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _wishlistsTableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_owner',
            value: userId,
          ),
          callback: (payload) => _loadData(key, controller, fetch),
        )
        .subscribe();

    _channels[key] = channel;

    return controller.stream;
  }

  /// Retourne le stream du controller existant de [key], ou null s'il n'y en a
  /// pas.
  Stream<T>? _existingStream<T>(
    String key,
    Future<T> Function() fetch,
  ) {
    // ignore: close_sinks - fermé dans _cleanupStream
    // Les clés ne doivent pas se recouper entre les méthodes watch* : le cast
    // suppose un même type de valeur par clé.
    final existing = _controllers[key] as BehaviorSubject<T>?;
    // Une erreur sans valeur : on relance un chargement pour qu'un retry
    // (ex: ref.invalidate) puisse réussir.
    if (existing != null && existing.hasError && !existing.hasValue) {
      _loadData(key, existing, fetch);
      // L'erreur en cache est celle qu'on retente : on n'en rejoue pas l'erreur
      // périmée, on attend le résultat du rechargement (valeur, ou nouvelle
      // erreur s'il échoue encore).
      return existing.skipReplayedError();
    }
    return existing?.stream;
  }

  BehaviorSubject<T> _createController<T>(String key) {
    late final BehaviorSubject<T> controller;
    controller = BehaviorSubject<T>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;
    return controller;
  }

  /// Charge une valeur avec [fetch] et l'émet sur [controller].
  ///
  /// Les rechargements ne sont pas séquencés. Un résultat n'est émis que s'il
  /// est plus récent que le dernier émis pour la clé : un résultat plus ancien
  /// qui termine après un plus récent est ignoré (sinon, rejoué par le
  /// [BehaviorSubject], il resterait en cache).
  ///
  /// Une erreur n'est émise que tant qu'aucune valeur n'a été émise et qu'aucun
  /// rechargement plus récent n'est en cours : sinon elle remplacerait la
  /// dernière bonne valeur pour les abonnés suivants, ou un résultat à venir.
  Future<void> _loadData<T>(
    String key,
    BehaviorSubject<T> controller,
    Future<T> Function() fetch,
  ) async {
    // Un controller fermé (ex: callback tardif d'un ancien channel) ne doit pas
    // avancer la génération partagée, il rendrait périmé le chargement du
    // nouveau controller de la même clé.
    if (controller.isClosed) {
      return;
    }
    final generation = _loadGenerations[key] = (_loadGenerations[key] ?? 0) + 1;

    try {
      final value = await fetch();
      if (controller.isClosed ||
          generation <= (_emittedGenerations[key] ?? 0)) {
        return;
      }
      _emittedGenerations[key] = generation;
      controller.add(value);
    } catch (e, st) {
      if (controller.isClosed || _loadGenerations[key] != generation) {
        return;
      }
      if (controller.hasValue) {
        debugPrint('[Wishy wishlists] reload failed, keeping last value: $e');
        debugPrint(st.toString());
      } else {
        controller.addError(e, st);
      }
    }
  }

  void _cleanupStream(String key, BehaviorSubject<dynamic> controller) {
    // Ignore un cancel tardif d'un ancien controller si la clé a été reprise
    // par un nouveau.
    if (!identical(_controllers[key], controller)) {
      return;
    }
    // Sans risque : [_loadData] ignore les controllers fermés.
    _loadGenerations.remove(key);
    _emittedGenerations.remove(key);
    _channels[key]?.unsubscribe();
    _channels.remove(key);
    controller.close();
    _controllers.remove(key);
  }

  @override
  Future<void> dispose() async {
    // Fermer un subject peut déclencher onCancel -> _cleanupStream, qui modifie
    // les maps : on itère sur des copies.
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
