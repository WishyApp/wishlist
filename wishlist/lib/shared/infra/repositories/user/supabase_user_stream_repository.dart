import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/user/user_stream_repository.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/utils/skip_replayed_error.dart';

class SupabaseUserStreamRepository implements UserStreamRepository {
  SupabaseUserStreamRepository(this._client);

  final SupabaseClient _client;
  static const _profilesTableName = 'profiles';

  final Map<String, RealtimeChannel> _channels = {};

  /// Chaque controller est un [BehaviorSubject] (et non un
  /// `StreamController.broadcast`, qui ne rejoue rien) : un abonné qui arrive
  /// après le premier chargement (ex: un second provider sur le même profil)
  /// reçoit tout de suite la dernière valeur, puis les suivantes.
  /// `onCancel` se déclenche quand le dernier abonné part.
  final Map<String, BehaviorSubject<Profile?>> _controllers = {};

  /// Numéro du dernier chargement lancé par clé, voir [_loadData].
  final Map<String, int> _loadGenerations = {};

  /// Numéro du dernier chargement émis par clé, voir [_loadData].
  final Map<String, int> _emittedGenerations = {};

  @override
  Stream<Profile?> watchProfileById(String userId) {
    final key = 'profile_$userId';

    Future<Profile?> fetch() async {
      final response = await _client
          .from(_profilesTableName)
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response == null ? null : Profile.fromJson(response);
    }

    // ignore: close_sinks - fermé dans _cleanupStream
    final existingController = _controllers[key];
    if (existingController != null) {
      // Une erreur sans valeur : on relance un chargement pour qu'un retry
      // (ex: ref.invalidate) puisse réussir.
      if (existingController.hasError && !existingController.hasValue) {
        _loadData(key, existingController, fetch);
        // L'erreur en cache est celle qu'on retente : on n'en rejoue pas
        // l'erreur périmée, on attend le résultat du rechargement (valeur, ou
        // nouvelle erreur s'il échoue encore).
        return existingController.skipReplayedError();
      }
      return existingController.stream;
    }

    late final BehaviorSubject<Profile?> controller;
    controller = BehaviorSubject<Profile?>(
      onCancel: () => _cleanupStream(key, controller),
    );
    _controllers[key] = controller;

    _loadData(key, controller, fetch);

    final channel = _client
        .channel('profile_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _profilesTableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          // Le profil est lu dans le payload, mais passe par le même
          // séquencement que les chargements : un chargement plus ancien qui
          // termine après lui ne l'écrase pas.
          callback: (payload) => _loadData(
            key,
            controller,
            () async => payload.eventType == PostgresChangeEvent.delete
                ? null
                : Profile.fromJson(payload.newRecord),
          ),
        )
        .subscribe();

    _channels[key] = channel;

    return controller.stream;
  }

  /// Charge le profil avec [fetch] et l'émet sur [controller].
  ///
  /// Les chargements ne sont pas séquencés. Un résultat n'est émis que s'il
  /// est plus récent que le dernier émis pour la clé : un résultat plus ancien
  /// qui termine après un plus récent est ignoré (sinon, rejoué par le
  /// [BehaviorSubject], il resterait en cache).
  ///
  /// Une erreur n'est émise que tant qu'aucune valeur n'a été émise et qu'aucun
  /// chargement plus récent n'est en cours : sinon elle remplacerait la
  /// dernière bonne valeur pour les abonnés suivants, ou un résultat à venir.
  Future<void> _loadData(
    String key,
    BehaviorSubject<Profile?> controller,
    Future<Profile?> Function() fetch,
  ) async {
    // Un controller fermé (ex: callback tardif d'un ancien channel) ne doit pas
    // avancer la génération partagée, il rendrait périmé le chargement du
    // nouveau controller de la même clé.
    if (controller.isClosed) {
      return;
    }
    final generation = _loadGenerations[key] = (_loadGenerations[key] ?? 0) + 1;

    try {
      final profile = await fetch();
      if (controller.isClosed ||
          generation <= (_emittedGenerations[key] ?? 0)) {
        return;
      }
      _emittedGenerations[key] = generation;
      controller.add(profile);
    } catch (e, st) {
      if (controller.isClosed || _loadGenerations[key] != generation) {
        return;
      }
      if (controller.hasValue) {
        debugPrint('[Wishy profile] reload failed, keeping last value: $e');
        debugPrint(st.toString());
      } else {
        controller.addError(e, st);
      }
    }
  }

  void _cleanupStream(String key, BehaviorSubject<Profile?> controller) {
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
