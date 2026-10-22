import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wishlist/shared/utils/skip_replayed_error.dart';

void main() {
  test('drops the error replayed by a BehaviorSubject, keeps the next events',
      () async {
    final subject = BehaviorSubject<int>()..addError(Exception('stale'));

    final values = <int>[];
    final errors = <Object>[];
    final sub =
        subject.skipReplayedError().listen(values.add, onError: errors.add);
    await pumpEventQueue();
    expect(errors, isEmpty);

    subject
      ..add(1)
      ..addError(Exception('fresh'));
    await pumpEventQueue();

    expect(values, [1]);
    expect(errors, hasLength(1));
    expect(errors.single.toString(), contains('fresh'));

    await sub.cancel();
    await subject.close();
  });

  test('a new error arriving before the listen is not swallowed', () async {
    final subject = BehaviorSubject<int>()..addError(Exception('stale'));

    final stream = subject.skipReplayedError();
    // The reload fails before the subscriber actually listens.
    subject.addError(Exception('fresh'));

    final errors = <Object>[];
    final sub = stream.listen((_) {}, onError: errors.add);
    await pumpEventQueue();

    expect(errors, hasLength(1));
    expect(errors.single.toString(), contains('fresh'));

    await sub.cancel();
    await subject.close();
  });
}
