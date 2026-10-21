import 'dart:async';

import 'package:rxdart/rxdart.dart';

extension SkipReplayedErrorExtension<T> on BehaviorSubject<T> {
  /// Le stream du subject, sans l'erreur en cache rejouée au nouvel abonné.
  ///
  /// Un `BehaviorSubject` rejoue son erreur en cache à l'abonné, et
  /// `Stream.skip` ne compte que les données : il laisserait passer cette
  /// erreur. L'erreur en cache est capturée à l'appel : seule la première
  /// erreur du stream, et seulement si c'est elle (`identical`), est ignorée.
  /// Une nouvelle erreur arrivée avant l'abonnement n'est pas avalée.
  ///
  /// À utiliser pour un abonné unique, quand l'erreur en cache est celle qu'on
  /// est en train de retenter.
  Stream<T> skipReplayedError() {
    final stale = errorOrNull;
    var checked = false;
    return stream.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          final isStale = !checked && stale != null && identical(error, stale);
          checked = true;
          if (!isStale) {
            sink.addError(error, stackTrace);
          }
        },
      ),
    );
  }
}
