import 'dart:async';

/// Default time a screen waits for its first data before showing an error.
const firstEventTimeLimit = Duration(seconds: 15);

extension FirstEventTimeout<T> on Stream<T> {
  /// Emits a [TimeoutException] if the stream sends nothing (neither event nor
  /// error) within [timeLimit] after being listened to.
  ///
  /// Unlike [Stream.timeout], only the first event is awaited: a realtime
  /// stream can then stay silent as long as nothing changes. The stream is not
  /// closed on timeout, so a late first event still gets through.
  Stream<T> timeoutFirstEvent([Duration timeLimit = firstEventTimeLimit]) {
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? timer;

    controller = StreamController<T>(
      onListen: () {
        timer = Timer(timeLimit, () {
          controller.addError(
            TimeoutException('No event received', timeLimit),
          );
        });
        subscription = listen(
          (event) {
            timer?.cancel();
            controller.add(event);
          },
          onError: (Object error, StackTrace stackTrace) {
            timer?.cancel();
            controller.addError(error, stackTrace);
          },
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        timer?.cancel();
        return subscription?.cancel();
      },
    );

    return controller.stream;
  }
}
