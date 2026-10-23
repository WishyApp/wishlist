import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/utils/skip_replayed_error.dart';

/// Relance un chargement pour la clé. Sans argument, il rejoue le chargement
/// passé à [KeyedRealtimeStreams.watch] ; avec [override], il charge cette
/// valeur à la place (ex: un payload realtime appliqué directement) en gardant
/// le même séquencement.
typedef Reload<T> = Future<void> Function([Future<T> Function()? override]);

/// Flux de données rechargées à la demande, un par clé, rafraîchis par un
/// channel Realtime. Les repositories de flux y délèguent la mécanique
/// commune ; ils gardent leurs requêtes et leurs filtres de channel.
///
/// Chaque flux est un [BehaviorSubject] (et non un
/// `StreamController.broadcast`, qui ne rejoue rien) : un abonné qui arrive
/// après le premier chargement reçoit tout de suite la dernière valeur, puis
/// les suivantes. Le channel et le subject sont libérés quand le dernier
/// abonné part.
///
/// Le channel est abonné ici (le `channelBuilder` le retourne non abonné) pour
/// que tous les flux partagent la même gestion de son statut :
///
/// - `subscribed` : on recharge. Realtime ne rejoue pas les changements
///   validés pendant qu'on n'était pas abonné : ni ceux survenus entre le
///   premier chargement et le premier `subscribed`, ni ceux manqués pendant
///   une coupure (la reprise de l'app en arrière-plan rejoint le channel et
///   renvoie `subscribed`). Les générations de [_load] absorbent le
///   chargement en plus. Les autres statuts ne disent rien du contenu.
/// - `timedOut` : realtime_client relance lui-même le join (son timer de
///   rejoin), on se contente de loguer ; le `subscribed` qui suit recharge.
/// - `channelError` : une erreur du channel lui-même (socket coupé) est aussi
///   rejointe seule, mais une réponse d'erreur au join, ou un événement
///   système en erreur après `subscribed` (réplication postgres_changes
///   refusée, ex: RLS avec un JWT expiré), n'est suivie d'aucune reprise : le
///   channel peut rester « joint » sans rien livrer. On ne sait pas les
///   distinguer, on abandonne donc le channel et on en abonne un neuf après un
///   délai croissant ([retryDelays]). Si le channel se rejoint seul entre-temps
///   (`subscribed`), la reprise en attente est annulée. Tant que le socket
///   Realtime est coupé (ex: l'OS l'a fermé en arrière-plan), on ne remplace
///   rien : realtime_client se reconnecte et rejoint lui-même tous les
///   channels, le `subscribed` qui suit recharge et annule la reprise. Le
///   délai est simplement rearmé ; on ne remplace le channel que socket
///   connecté (réponse d'erreur au join, ou erreur système après `subscribed`).
///
/// Aucun rafraîchissement explicite de la session : supabase_flutter pousse
/// les jetons rafraîchis vers realtime, et le channel neuf, abonné après le
/// délai, utilise le jeton courant.
///
/// Une instance appartient à un repository, qui doit appeler [dispose].
class KeyedRealtimeStreams {
  /// [logTag] préfixe les logs d'un rechargement en échec.
  ///
  /// [shouldEmitErrorAfterValue] décide si une erreur survenue après une
  /// première valeur doit quand même être émise (par défaut, elle est
  /// seulement loguée et la dernière valeur est conservée).
  ///
  /// [retryDelays] sont les délais avant de réabonner un channel en erreur,
  /// par tentative consécutive ; le dernier est répété. Le compteur repart de
  /// zéro à chaque `subscribed`.
  KeyedRealtimeStreams({
    required this.logTag,
    this.shouldEmitErrorAfterValue,
    this.retryDelays = defaultRetryDelays,
    this.isSocketConnected,
  }) : assert(retryDelays.isNotEmpty, 'retryDelays must not be empty');

  static const defaultRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  final String logTag;
  final bool Function(Object error)? shouldEmitErrorAfterValue;
  final List<Duration> retryDelays;

  /// Dit si le socket Realtime est connecté (`client.realtime.isConnected`) ;
  /// `RealtimeChannel.socket` est interne à realtime_client. Sans lui, le
  /// socket est supposé connecté.
  final bool Function()? isSocketConnected;

  final Map<String, RealtimeChannel> _channels = {};

  /// Réabonnements en attente par clé (un seul à la fois, voir
  /// [_scheduleResubscribe]).
  final Map<String, Timer> _retryTimers = {};

  /// Nombre de réabonnements déjà planifiés par clé depuis le dernier
  /// `subscribed`, qui choisit le délai suivant.
  final Map<String, int> _retryAttempts = {};

  /// Le type de valeur dépend de la clé : [watch] recaste le subject avec le
  /// type de la clé, une même clé ne doit donc pas servir à deux types.
  final Map<String, BehaviorSubject<dynamic>> _controllers = {};

  /// Numéro du dernier chargement lancé par clé, voir [_load].
  final Map<String, int> _loadGenerations = {};

  /// Numéro du dernier chargement émis par clé, voir [_load].
  final Map<String, int> _emittedGenerations = {};

  /// Retourne le flux de [key], le crée au premier appel.
  ///
  /// À la création, [load] est lancé puis [channelBuilder] construit le channel
  /// qui rafraîchit le flux : il reçoit la fonction de rechargement à appeler à
  /// chaque changement, et retourne le channel avec ses `onPostgresChanges`
  /// mais **sans** l'abonner, c'est [KeyedRealtimeStreams] qui s'en charge.
  /// [channelBuilder] peut être rappelé pour réabonner un channel neuf après
  /// une erreur : il doit créer un nouveau channel à chaque appel.
  ///
  /// Si [skipEqual], une valeur égale (`==`) à la valeur courante n'est pas
  /// ré-émise (les abonnés rechargent des données en aval).
  Stream<T> watch<T>(
    String key, {
    required Future<T> Function() load,
    required RealtimeChannel Function(Reload<T> reload) channelBuilder,
    bool skipEqual = false,
  }) {
    // ignore: close_sinks - fermé dans _cleanup
    final existing = _controllers[key] as BehaviorSubject<T>?;
    if (existing != null) {
      // Une erreur sans valeur : on relance un chargement pour qu'un retry
      // (ex: ref.invalidate) puisse réussir.
      if (existing.hasError && !existing.hasValue) {
        _load(key, existing, load, skipEqual);
        // L'erreur en cache est celle qu'on retente : on n'en rejoue pas
        // l'erreur périmée, on attend le résultat du rechargement (valeur, ou
        // nouvelle erreur s'il échoue encore).
        return existing.skipReplayedError();
      }
      return existing.stream;
    }

    late final BehaviorSubject<T> controller;
    controller = BehaviorSubject<T>(
      onCancel: () => _cleanup(key, controller),
    );
    _controllers[key] = controller;

    Future<void> reload([Future<T> Function()? override]) =>
        _load(key, controller, override ?? load, skipEqual);
    reload();

    _subscribe(key, controller, channelBuilder(reload), channelBuilder, reload);

    return controller.stream;
  }

  /// Abonne [channel], enregistré pour [key], et réagit à son statut (voir la
  /// doc de la classe). Les statuts d'un channel remplacé, ou d'une clé
  /// nettoyée, sont ignorés.
  void _subscribe<T>(
    String key,
    BehaviorSubject<T> controller,
    RealtimeChannel channel,
    RealtimeChannel Function(Reload<T> reload) channelBuilder,
    Reload<T> reload,
  ) {
    _channels[key] = channel;
    channel.subscribe((status, error) {
      if (!identical(_controllers[key], controller) ||
          !identical(_channels[key], channel)) {
        return;
      }
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _retryTimers.remove(key)?.cancel();
          _retryAttempts.remove(key);
          reload();
        case RealtimeSubscribeStatus.timedOut:
          debugPrint('[Wishy $logTag] channel $key timed out, retrying');
        case RealtimeSubscribeStatus.channelError:
          debugPrint('[Wishy $logTag] channel $key error: $error');
          _scheduleResubscribe(
            key,
            controller,
            channel,
            channelBuilder,
            reload,
          );
        case RealtimeSubscribeStatus.closed:
          break;
      }
    });
  }

  /// Planifie le remplacement de [channel] par un channel neuf, après un délai
  /// croissant. Sans effet si un remplacement est déjà planifié pour la clé
  /// (erreurs en rafale d'un même channel).
  void _scheduleResubscribe<T>(
    String key,
    BehaviorSubject<T> controller,
    RealtimeChannel channel,
    RealtimeChannel Function(Reload<T> reload) channelBuilder,
    Reload<T> reload,
  ) {
    if (_retryTimers.containsKey(key)) {
      return;
    }
    final attempt = _retryAttempts[key] ?? 0;
    _retryAttempts[key] = attempt + 1;
    final delay = retryDelays[min(attempt, retryDelays.length - 1)];

    _retryTimers[key] = Timer(delay, () {
      _retryTimers.remove(key);
      // Un cleanup ou un dispose a pu passer entre-temps.
      if (!identical(_controllers[key], controller) ||
          !identical(_channels[key], channel)) {
        return;
      }
      // Socket coupé : la bibliothèque le reconnecte et rejoint seule ses
      // channels, remplacer le nôtre ne ferait que rouvrir le socket pour rien.
      if (!(isSocketConnected?.call() ?? true)) {
        debugPrint('[Wishy $logTag] socket down, leaving $key to the client');
        _scheduleResubscribe(key, controller, channel, channelBuilder, reload);
        return;
      }
      debugPrint('[Wishy $logTag] resubscribing channel $key');
      // Le leave part sans attendre sa réponse : le client retire le channel
      // de sa liste à la fermeture, et un channel neuf n'a pas à l'attendre.
      unawaited(_leave(channel));
      try {
        _subscribe(
          key,
          controller,
          channelBuilder(reload),
          channelBuilder,
          reload,
        );
      } catch (e, st) {
        debugPrint('[Wishy $logTag] resubscribe of $key failed: $e');
        debugPrint(st.toString());
        _scheduleResubscribe(key, controller, channel, channelBuilder, reload);
      }
    });
  }

  Future<void> _leave(RealtimeChannel channel) async {
    try {
      await channel.unsubscribe();
    } catch (e) {
      debugPrint('[Wishy $logTag] leaving a channel failed: $e');
    }
  }

  /// Charge une valeur avec [load] et l'émet sur [controller].
  ///
  /// Les rechargements ne sont pas séquencés. Un résultat n'est émis que s'il
  /// est plus récent que le dernier émis pour la clé : un résultat plus ancien
  /// qui termine après un plus récent est ignoré (sinon, rejoué par le
  /// [BehaviorSubject], il resterait en cache), mais un plus ancien qui termine
  /// avant est gardé, il évite d'attendre le suivant.
  ///
  /// Une erreur n'est émise que tant qu'aucune valeur n'a été émise et qu'aucun
  /// rechargement plus récent n'est en cours : sinon elle remplacerait la
  /// dernière bonne valeur pour les abonnés suivants, ou un résultat à venir.
  /// [shouldEmitErrorAfterValue] peut la faire émettre quand même.
  Future<void> _load<T>(
    String key,
    BehaviorSubject<T> controller,
    Future<T> Function() load,
    bool skipEqual,
  ) async {
    // Un controller fermé (ex: callback tardif d'un ancien channel) ne doit pas
    // avancer la génération partagée, il rendrait périmé le chargement du
    // nouveau controller de la même clé.
    if (controller.isClosed) {
      return;
    }
    final generation = _loadGenerations[key] = (_loadGenerations[key] ?? 0) + 1;

    try {
      final value = await load();
      if (controller.isClosed ||
          generation <= (_emittedGenerations[key] ?? 0)) {
        return;
      }
      _emittedGenerations[key] = generation;
      if (!skipEqual || !controller.hasValue || controller.value != value) {
        controller.add(value);
      }
    } catch (e, st) {
      if (controller.isClosed || _loadGenerations[key] != generation) {
        return;
      }
      final emitAfterValue = shouldEmitErrorAfterValue?.call(e) ?? false;
      if (controller.hasValue && !emitAfterValue) {
        debugPrint('[Wishy $logTag] reload failed, keeping last value: $e');
        debugPrint(st.toString());
      } else {
        // Une erreur acceptée par [shouldEmitErrorAfterValue] (ex: un wish
        // supprimé) n'est pas passagère : elle avance la génération émise, un
        // résultat plus ancien qui termine après elle ne doit pas la remplacer
        // (le subject le garderait et le rejouerait). Une erreur passagère
        // n'avance rien : un résultat plus ancien mais bon reste utile.
        if (emitAfterValue) {
          _emittedGenerations[key] = generation;
        }
        controller.addError(e, st);
      }
    }
  }

  void _cleanup(String key, BehaviorSubject<dynamic> controller) {
    // Ignore un cancel tardif d'un ancien controller (ex: pendant dispose) si
    // la clé a été reprise par un nouveau.
    if (!identical(_controllers[key], controller)) {
      return;
    }
    // Sans risque : [_load] ignore les controllers fermés, aucun ancien
    // chargement ne peut écrire dans la génération d'un futur controller.
    _loadGenerations.remove(key);
    _emittedGenerations.remove(key);
    _retryTimers.remove(key)?.cancel();
    _retryAttempts.remove(key);
    _channels[key]?.unsubscribe();
    _channels.remove(key);
    controller.close();
    _controllers.remove(key);
  }

  /// Ferme tous les channels puis tous les flux.
  ///
  /// Les channels sont quittés avec [RealtimeChannel.unsubscribe] et non
  /// `SupabaseClient.removeChannel` : dans realtime_client 2.11.0,
  /// `removeChannel` fait `unsubscribe` puis déconnecte le socket Realtime
  /// partagé si plus aucun channel n'y est enregistré, ce qui n'a pas de sens
  /// pour libérer une clé. `unsubscribe` envoie le leave et le client retire
  /// lui-même le channel de sa liste à la fermeture.
  Future<void> dispose() async {
    // Un cancel pendant les await déclenche onCancel -> _cleanup, qui modifie
    // _channels et _controllers : on itère donc sur des copies.
    final channels = _channels.values.toList();
    _channels.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryAttempts.clear();
    try {
      // Tous les leave partent ensemble, et un channel qui échoue n'empêche ni
      // les autres ni la fermeture des flux (l'erreur est relancée à la fin).
      await Future.wait(channels.map((channel) async => channel.unsubscribe()));
    } finally {
      final controllers = Map.of(_controllers);
      _controllers.clear();
      for (final controller in controllers.values) {
        await controller.close();
      }
      // Les générations des clés fermées : pas celles d'une clé reprise par un
      // nouveau controller pendant la fermeture.
      for (final key in controllers.keys) {
        if (!_controllers.containsKey(key)) {
          _loadGenerations.remove(key);
          _emittedGenerations.remove(key);
        }
      }
    }
  }
}
