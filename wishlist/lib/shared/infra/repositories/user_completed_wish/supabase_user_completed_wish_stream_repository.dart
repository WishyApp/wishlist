import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_stream_repository.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/utils/skip_replayed_error.dart';

class SupabaseUserCompletedWishStreamRepository
    implements UserCompletedWishStreamRepository {
  SupabaseUserCompletedWishStreamRepository(
    this._client,
    this._repository,
  );

  final SupabaseClient _client;
  final UserCompletedWishRepository _repository;
  static const _tableName = 'user_completed_wishs';

  final Map<String, RealtimeChannel> _channels = {};

  /// Chaque controller est un [BehaviorSubject] (et non un
  /// `StreamController.broadcast`, qui ne rejoue rien) : un abonné qui arrive
  /// après le premier chargement (ex: un second provider sur le même
  /// utilisateur) reçoit tout de suite la dernière valeur, puis les suivantes.
  /// `onCancel` se déclenche quand le dernier abonné part.
  final Map<String, BehaviorSubject<IList<CompletedWishWithDetails>>>
      _controllers = {};

  /// Numéro du dernier chargement lancé par clé, voir [_loadData].
  final Map<String, int> _loadGenerations = {};

  /// Numéro du dernier chargement émis par clé, voir [_loadData].
  final Map<String, int> _emittedGenerations = {};

  @override
  Stream<IList<CompletedWishWithDetails>> watchCompletedWishesByUser(
    String userId,
  ) {
    final key = 'completed_wishes_$userId';

    // ignore: close_sinks - fermé dans _cleanupStream
    final existingController = _controllers[key];
    if (existingController != null) {
      // Une erreur sans valeur : on relance un chargement pour qu'un retry
      // (ex: ref.invalidate) puisse réussir.
      if (existingController.hasError && !existingController.hasValue) {
        _loadData(key, userId, existingController);
        // L'erreur en cache est celle qu'on retente : on n'en rejoue pas
        // l'erreur périmée, on attend le résultat du rechargement (valeur, ou
        // nouvelle erreur s'il échoue encore).
        return existingController.skipReplayedError();
      }
      return existingController.stream;
    }

    late final BehaviorSubject<IList<CompletedWishWithDetails>> controller;
    controller = BehaviorSubject<IList<CompletedWishWithDetails>>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    _loadData(key, userId, controller);

    final channel = _client
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
          callback: (payload) => _loadData(key, userId, controller),
        )
        // Si un wish complété est modifié/supprimé
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'wishs',
          callback: (payload) => _loadData(key, userId, controller),
        )
        // Si la wishlist d'origine est renommée ou supprimée
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'wishlists',
          callback: (payload) => _loadData(key, userId, controller),
        )
        // Si le pseudo/avatar du propriétaire change
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) => _loadData(key, userId, controller),
        )
        .subscribe((status, _) {
      // Un changement validé entre le premier chargement et le passage du
      // channel à `subscribed` (ou pendant une reconnexion) n'arrive jamais en
      // événement : on recharge. Les générations absorbent le chargement en
      // plus.
      if (status == RealtimeSubscribeStatus.subscribed) {
        _loadData(key, userId, controller);
      }
    });

    _channels[key] = channel;

    return controller.stream;
  }

  /// Charge les wishs complétés et les émet sur [controller].
  ///
  /// Les rechargements ne sont pas séquencés. Un résultat n'est émis que s'il
  /// est plus récent que le dernier émis pour la clé : un résultat plus ancien
  /// qui termine après un plus récent est ignoré (sinon, rejoué par le
  /// [BehaviorSubject], il resterait en cache).
  ///
  /// Une erreur n'est émise que tant qu'aucune valeur n'a été émise et qu'aucun
  /// rechargement plus récent n'est en cours : sinon elle remplacerait la
  /// dernière bonne valeur pour les abonnés suivants, ou un résultat à venir.
  Future<void> _loadData(
    String key,
    String userId,
    BehaviorSubject<IList<CompletedWishWithDetails>> controller,
  ) async {
    // Un controller fermé (ex: callback tardif d'un ancien channel) ne doit pas
    // avancer la génération partagée, il rendrait périmé le chargement du
    // nouveau controller de la même clé.
    if (controller.isClosed) {
      return;
    }
    final generation = _loadGenerations[key] = (_loadGenerations[key] ?? 0) + 1;

    try {
      final completedWishes =
          await _repository.getCompletedWishesByUser(userId);
      if (controller.isClosed ||
          generation <= (_emittedGenerations[key] ?? 0)) {
        return;
      }
      _emittedGenerations[key] = generation;
      controller.add(completedWishes);
    } catch (e, st) {
      if (controller.isClosed || _loadGenerations[key] != generation) {
        return;
      }
      if (controller.hasValue) {
        debugPrint('[Wishy completed wishes] reload failed, keeping last '
            'value: $e');
        debugPrint(st.toString());
      } else {
        controller.addError(e, st);
      }
    }
  }

  void _cleanupStream(
    String key,
    BehaviorSubject<IList<CompletedWishWithDetails>> controller,
  ) {
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
  void dispose() {
    // Fermer un subject peut déclencher onCancel -> _cleanupStream, qui modifie
    // les maps : on itère sur des copies.
    final channels = _channels.values.toList();
    _channels.clear();
    for (final channel in channels) {
      channel.unsubscribe();
    }

    final controllers = _controllers.values.toList();
    _controllers.clear();
    for (final controller in controllers) {
      controller.close();
    }
  }
}
