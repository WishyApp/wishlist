import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_stream_repository.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/utils/skip_replayed_error.dart';

class SupabaseWishStreamRepository implements WishStreamRepository {
  SupabaseWishStreamRepository(
    this._client,
    this._wishRepository,
  );

  final SupabaseClient _client;
  final WishRepository _wishRepository;
  static const _wishsTableName = 'wishs';
  static const _wishTakenByUserTableName = 'wish_taken_by_user';
  static const _wishlistsTableName = 'wishlists';
  static const _canOwnerSeeTakenWishColumn = 'can_owner_see_taken_wish';

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
  Stream<IList<Wish>> watchWishsFromWishlist(int wishlistId) {
    final key = 'wishlist_$wishlistId';

    Future<IList<Wish>> fetch() =>
        _wishRepository.getWishsFromWishlist(wishlistId);

    // ignore: close_sinks - fermé dans _cleanupStream
    final existingStream = _existingStream<IList<Wish>>(key, fetch);
    if (existingStream != null) {
      return existingStream;
    }

    final controller = _createController<IList<Wish>>(key);
    void reload() => _loadData(key, controller, fetch);

    reload();

    final channel = _client
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
        // wish_taken_by_user ne bouge. wishlists est en REPLICA IDENTITY FULL,
        // l'ancienne valeur est donc fournie ; à défaut on recharge.
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
        )
        .subscribe();

    _channels[key] = channel;

    return controller.stream;
  }

  @override
  Stream<Wish> watchWishById(int wishId) {
    final key = 'wish_$wishId';

    Future<Wish> fetch() => _wishRepository.getWishById(wishId);

    // ignore: close_sinks - fermé dans _cleanupStream
    final existingStream = _existingStream<Wish>(key, fetch);
    if (existingStream != null) {
      return existingStream;
    }

    final controller = _createController<Wish>(key);
    void reload() => _loadData(key, controller, fetch);

    reload();

    final channel = _client
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
        )
        .subscribe();

    _channels[key] = channel;

    return controller.stream;
  }

  @override
  Stream<IList<BookedWishWithDetails>> watchBookedWishesByUser(String userId) {
    final key = 'booked_wishes_$userId';

    Future<IList<BookedWishWithDetails>> fetch() =>
        _wishRepository.getBookedWishesByUser(userId);

    // ignore: close_sinks - fermé dans _cleanupStream
    final existingStream =
        _existingStream<IList<BookedWishWithDetails>>(key, fetch);
    if (existingStream != null) {
      return existingStream;
    }

    final controller = _createController<IList<BookedWishWithDetails>>(key);
    void reload() => _loadData(key, controller, fetch);

    reload();

    // Écouter les changements sur wish_taken_by_user (réservations)
    final channel = _client
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
      // Un wish supprimé (ou masqué par la RLS) n'est pas une erreur
      // passagère : on l'émet même après une valeur, sinon il resterait
      // affiché.
      if (controller.hasValue && !_isNotFound(e)) {
        debugPrint('[Wishy wishs] reload failed, keeping last value: $e');
        debugPrint(st.toString());
      } else {
        // Un wish introuvable avance la génération émise : un résultat plus
        // ancien qui termine après lui (le wish d'avant sa suppression) ne doit
        // pas le remplacer, le subject le garderait et le rejouerait. Une
        // erreur passagère n'avance rien : un résultat plus ancien mais bon
        // reste utile.
        if (_isNotFound(e)) {
          _emittedGenerations[key] = generation;
        }
        controller.addError(e, st);
      }
    }
  }

  static bool _isNotFound(Object error) {
    if (error is! AppException) {
      return false;
    }
    final cause = error.cause;
    return cause is PostgrestException && cause.code == 'PGRST116';
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
