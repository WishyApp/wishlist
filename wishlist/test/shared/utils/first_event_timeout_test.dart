import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/utils/first_event_timeout.dart';

void main() {
  // Real timers: short enough to keep the suite fast, with margins wide
  // enough not to be flaky
  const timeLimit = Duration(milliseconds: 100);
  const beforeTimeLimit = Duration(milliseconds: 20);
  const afterTimeLimit = Duration(milliseconds: 250);

  group('timeoutFirstEvent', () {
    late StreamController<int> source;
    late List<int> events;
    late List<Object> errors;
    late StreamSubscription<int> subscription;

    setUp(() {
      source = StreamController<int>();
      events = [];
      errors = [];
      subscription = source.stream
          .timeoutFirstEvent(timeLimit)
          .listen(events.add, onError: errors.add);
    });

    tearDown(() async {
      await subscription.cancel();
      // Never awaited: the source is cancelled before being done
      unawaited(source.close());
    });

    test('emits a TimeoutException when nothing comes in time', () async {
      await Future<void>.delayed(beforeTimeLimit);
      expect(errors, isEmpty);

      await Future<void>.delayed(afterTimeLimit);
      expect(errors, [isA<TimeoutException>()]);
    });

    test('still delivers a first event that comes after the timeout', () async {
      await Future<void>.delayed(afterTimeLimit);
      source.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(events, [1]);
    });

    test('lets the stream stay silent after its first event', () async {
      source.add(1);
      await Future<void>.delayed(afterTimeLimit);

      expect(events, [1]);
      expect(errors, isEmpty);
    });

    test('passes a first error through without adding a timeout', () async {
      source.addError(StateError('boom'));
      await Future<void>.delayed(afterTimeLimit);

      expect(errors, [isA<StateError>()]);
    });

    test('stops the timer and the source when cancelled', () async {
      await subscription.cancel();
      await Future<void>.delayed(afterTimeLimit);

      expect(errors, isEmpty);
      expect(source.hasListener, false);
    });
  });
}
