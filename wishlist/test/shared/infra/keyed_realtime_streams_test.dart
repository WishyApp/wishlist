import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/keyed_realtime_streams.dart';

import '../../fixtures/mock_supabase.dart';

void main() {
  late MockRealtimeChannel channel;
  late List<MockRealtimeChannel> channels;
  late KeyedRealtimeStreams streams;

  MockRealtimeChannel newChannel() {
    final created = MockRealtimeChannel();
    when(created.unsubscribe).thenAnswer((_) async => 'ok');
    channels.add(created);
    return created;
  }

  setUp(() {
    channels = [];
    channel = newChannel();
    streams = KeyedRealtimeStreams(logTag: 'test');
  });

  tearDown(() => streams.dispose());

  /// Surveille [key] en capturant la fonction de rechargement du channel.
  Stream<T> watch<T>(
    String key,
    Future<T> Function() load, {
    void Function(Reload<T> reload)? onReload,
    bool skipEqual = false,
    RealtimeChannel? channelToUse,
  }) =>
      streams.watch<T>(
        key,
        load: load,
        skipEqual: skipEqual,
        channelBuilder: (reload) {
          onReload?.call(reload);
          return channelToUse ?? channel;
        },
      );

  group('replay', () {
    test('a late subscriber gets the current value, loaded once', () async {
      var loads = 0;
      Future<int> load() async => ++loads;

      final first = <int>[];
      final firstSub = watch('k', load).listen(first.add);
      await pumpEventQueue();

      final second = <int>[];
      final secondSub = watch('k', load).listen(second.add);
      await pumpEventQueue();

      expect(first, [1]);
      expect(second, [1]);
      expect(loads, 1);
      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('keys are independent', () async {
      final a = <int>[];
      final b = <String>[];
      final subA = watch('a', () async => 1).listen(a.add);
      final subB = watch('b', () async => 'x').listen(b.add);
      await pumpEventQueue();

      expect(a, [1]);
      expect(b, ['x']);
      await subA.cancel();
      await subB.cancel();
    });
  });

  group('load generations', () {
    test('an older result finishing after a newer one is ignored', () async {
      late Reload<int> reload;
      final loads = [Completer<int>(), Completer<int>()];
      var call = 0;

      final received = <int>[];
      final sub = watch<int>(
        'k',
        () => loads[call++].future,
        onReload: (r) => reload = r,
      ).listen(received.add);
      unawaited(reload());

      loads[1].complete(2);
      await pumpEventQueue();
      loads[0].complete(1);
      await pumpEventQueue();

      expect(received, [2]);
      await sub.cancel();
    });

    test('an older result finishing before a newer one is kept', () async {
      late Reload<int> reload;
      final loads = [Completer<int>(), Completer<int>()];
      var call = 0;

      final received = <int>[];
      final sub = watch<int>(
        'k',
        () => loads[call++].future,
        onReload: (r) => reload = r,
      ).listen(received.add);
      unawaited(reload());

      loads[0].complete(1);
      await pumpEventQueue();
      loads[1].complete(2);
      await pumpEventQueue();

      expect(received, [1, 2]);
      await sub.cancel();
    });

    test('reload with an override loads that value in sequence', () async {
      late Reload<int> reload;
      final first = Completer<int>();

      final received = <int>[];
      final sub = watch<int>(
        'k',
        () => first.future,
        onReload: (r) => reload = r,
      ).listen(received.add);

      unawaited(reload(() async => 5));
      await pumpEventQueue();
      first.complete(1);
      await pumpEventQueue();

      expect(received, [5]);
      await sub.cancel();
    });

    test('a late result of a closed controller does not stale the new one',
        () async {
      late Reload<int> oldReload;
      final oldLoad = Completer<int>();
      var oldLoads = 0;

      final oldSub = watch<int>(
        'k',
        () {
          oldLoads++;
          return oldLoads == 1 ? Future.value(1) : oldLoad.future;
        },
        onReload: (r) => oldReload = r,
      ).listen((_) {});
      await pumpEventQueue();
      await oldSub.cancel();

      // La clé est reprise par un nouveau controller, qui charge lentement.
      final newLoad = Completer<int>();
      final received = <int>[];
      final newSub = watch<int>(
        'k',
        () => newLoad.future,
        channelToUse: newChannel(),
      ).listen(received.add);

      // Callback tardif de l'ancien channel : ignoré, sans avancer la
      // génération du nouveau controller.
      await oldReload();
      newLoad.complete(7);
      await pumpEventQueue();

      expect(received, [7]);
      await newSub.cancel();
    });
  });

  group('error policy', () {
    test('an error before the first value is emitted', () async {
      final errors = <Object>[];
      final sub = watch<int>('k', () async => throw StateError('boom'))
          .listen((_) {}, onError: errors.add);
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      await sub.cancel();
    });

    test('an error after a value is not emitted and the value is kept',
        () async {
      late Reload<int> reload;
      var fail = false;
      final received = <int>[];
      final errors = <Object>[];
      final sub = watch<int>(
        'k',
        () async => fail ? throw StateError('boom') : 1,
        onReload: (r) => reload = r,
      ).listen(received.add, onError: errors.add);
      await pumpEventQueue();

      fail = true;
      await reload();

      final late = <int>[];
      final lateSub = watch<int>('k', () async => 2).listen(late.add);
      await pumpEventQueue();

      expect(received, [1]);
      expect(errors, isEmpty);
      expect(late, [1]);
      await sub.cancel();
      await lateSub.cancel();
    });

    test('shouldEmitErrorAfterValue lets an error through after a value',
        () async {
      streams = KeyedRealtimeStreams(
        logTag: 'test',
        shouldEmitErrorAfterValue: (e) => e is FormatException,
      );
      late Reload<int> reload;
      Exception? failure;
      final received = <int>[];
      final errors = <Object>[];
      final sub = watch<int>(
        'k',
        () async => failure == null ? 1 : throw failure,
        onReload: (r) => reload = r,
      ).listen(received.add, onError: errors.add);
      await pumpEventQueue();

      failure = Exception('transient');
      await reload();
      expect(errors, isEmpty);

      failure = const FormatException('gone');
      await reload();
      await pumpEventQueue();

      expect(received, [1]);
      expect(errors.single, isA<FormatException>());
      await sub.cancel();
    });

    test(
        'an error emitted after a value (shouldEmitErrorAfterValue), then an '
        'older reload finishing later: the error stays', () async {
      streams = KeyedRealtimeStreams(
        logTag: 'test',
        shouldEmitErrorAfterValue: (e) => e is FormatException,
      );
      late Reload<int> reload;
      final loads = [Completer<int>(), Completer<int>(), Completer<int>()];
      var call = 0;
      final received = <int>[];
      final errors = <Object>[];
      final sub = watch<int>(
        'k',
        () => loads[call++].future,
        onReload: (r) => reload = r,
      ).listen(received.add, onError: errors.add);
      loads[0].complete(1);
      await pumpEventQueue();

      // Un rechargement lent démarre, puis le suivant échoue vite.
      unawaited(reload());
      unawaited(reload());
      loads[2].completeError(const FormatException('gone'));
      await pumpEventQueue();
      expect(errors, hasLength(1));

      // Le plus ancien termine après l'erreur : il ne la remplace pas.
      loads[1].complete(2);
      await pumpEventQueue();

      final late = <int>[];
      final lateErrors = <Object>[];
      final lateSub = watch<int>(
        'k',
        () => loads[call++].future,
      ).listen(late.add, onError: lateErrors.add);
      await pumpEventQueue();

      expect(received, [1]);
      expect(errors, hasLength(1));
      expect(late, isEmpty);
      expect(lateErrors, hasLength(1));
      await sub.cancel();
      await lateSub.cancel();
    });

    test('a transient error, then an older slower load: the value is emitted',
        () async {
      late Reload<int> reload;
      final loads = [Completer<int>(), Completer<int>()];
      var call = 0;
      final received = <int>[];
      final errors = <Object>[];
      final sub = watch<int>(
        'k',
        () => loads[call++].future,
        onReload: (r) => reload = r,
      ).listen(received.add, onError: errors.add);

      // Deux chargements en vol : le second échoue vite.
      unawaited(reload());
      loads[1].completeError(Exception('transient'));
      await pumpEventQueue();
      expect(errors, hasLength(1));

      loads[0].complete(1);
      await pumpEventQueue();

      expect(received, [1]);
      await sub.cancel();
    });

    test('an error superseded by a newer load is dropped', () async {
      late Reload<int> reload;
      final loads = [Completer<int>(), Completer<int>()];
      var call = 0;
      final received = <int>[];
      final errors = <Object>[];
      final sub = watch<int>(
        'k',
        () => loads[call++].future,
        onReload: (r) => reload = r,
      ).listen(received.add, onError: errors.add);
      unawaited(reload());

      loads[0].completeError(StateError('stale'));
      await pumpEventQueue();
      loads[1].complete(2);
      await pumpEventQueue();

      expect(errors, isEmpty);
      expect(received, [2]);
      await sub.cancel();
    });
  });

  group('skipEqual', () {
    test('without it, an equal value is emitted again', () async {
      late Reload<int> reload;
      final received = <int>[];
      final sub = watch<int>(
        'k',
        () async => 1,
        onReload: (r) => reload = r,
      ).listen(received.add);
      await pumpEventQueue();

      await reload();
      await pumpEventQueue();

      expect(received, [1, 1]);
      await sub.cancel();
    });

    test('with it, an equal value is skipped', () async {
      late Reload<int> reload;
      final received = <int>[];
      final sub = watch<int>(
        'k',
        () async => 1,
        skipEqual: true,
        onReload: (r) => reload = r,
      ).listen(received.add);
      await pumpEventQueue();

      await reload();
      await reload(() async => 2);
      await pumpEventQueue();

      expect(received, [1, 2]);
      await sub.cancel();
    });
  });

  group('reload on an error-only subject', () {
    test('a new subscriber triggers a reload that can succeed', () async {
      var loads = 0;
      Future<int> load() async {
        loads++;
        if (loads == 1) {
          throw StateError('boom');
        }
        return 42;
      }

      final firstSub = watch<int>('k', load).listen((_) {}, onError: (_) {});
      await pumpEventQueue();

      final received = <int>[];
      final errors = <Object>[];
      // L'erreur en cache est celle qu'on retente : elle n'est pas rejouée.
      final secondSub =
          watch<int>('k', load).listen(received.add, onError: errors.add);
      await pumpEventQueue();

      expect(loads, 2);
      expect(received, [42]);
      expect(errors, isEmpty);
      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('a retry that fails again emits the new error, not the stale one',
        () async {
      var loads = 0;
      Future<int> load() async => throw StateError('boom ${++loads}');

      final firstSub = watch<int>('k', load).listen((_) {}, onError: (_) {});
      await pumpEventQueue();

      final errors = <Object>[];
      final secondSub =
          watch<int>('k', load).listen((_) {}, onError: errors.add);
      await pumpEventQueue();

      expect(loads, 2);
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('boom 2'));
      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('does not reload when the subject has a value', () async {
      var loads = 0;
      Future<int> load() async => ++loads;

      final firstSub = watch<int>('k', load).listen((_) {});
      await pumpEventQueue();
      final secondSub = watch<int>('k', load).listen((_) {});
      await pumpEventQueue();

      expect(loads, 1);
      await firstSub.cancel();
      await secondSub.cancel();
    });
  });

  group('cleanup', () {
    test('the channel is unsubscribed only when the last listener leaves',
        () async {
      final firstSub = watch<int>('k', () async => 1).listen((_) {});
      final secondSub = watch<int>('k', () async => 1).listen((_) {});
      await pumpEventQueue();

      await firstSub.cancel();
      verifyNever(channel.unsubscribe);

      await secondSub.cancel();
      verify(channel.unsubscribe).called(1);
    });

    test('a new watch after cleanup builds a new controller and channel',
        () async {
      var built = 0;
      final sub = watch<int>(
        'k',
        () async => 1,
        onReload: (_) => built++,
      ).listen((_) {});
      await pumpEventQueue();
      await sub.cancel();

      final received = <int>[];
      final newSub = watch<int>(
        'k',
        () async => 2,
        onReload: (_) => built++,
        channelToUse: newChannel(),
      ).listen(received.add);
      await pumpEventQueue();

      expect(built, 2);
      expect(received, [2]);
      await newSub.cancel();
    });

    test(
        'a cancel of a closed controller does not tear down the one that '
        'took its key', () async {
      final otherChannel = newChannel();
      final retakenChannel = newChannel();
      Stream<int>? retaken;

      // Fermé en premier par dispose, `a` reprend la clé `b` avant que
      // l'ancien subject de `b` ne reçoive son cancel.
      watch<int>('a', () async => 1).listen(
        (_) {},
        onDone: () => retaken = watch<int>(
          'b',
          () async => 2,
          channelToUse: retakenChannel,
        ),
      );
      watch<int>('b', () async => 1, channelToUse: otherChannel).listen((_) {});
      await pumpEventQueue();

      await streams.dispose();
      await pumpEventQueue();

      var isDone = false;
      final received = <int>[];
      final sub = retaken!.listen(received.add, onDone: () => isDone = true);
      await pumpEventQueue();

      verifyNever(retakenChannel.unsubscribe);
      expect(isDone, isFalse);
      expect(received, [2]);
      await sub.cancel();
      verify(retakenChannel.unsubscribe).called(1);
    });
  });

  group('dispose', () {
    test('unsubscribes every channel and ends the streams', () async {
      final otherChannel = newChannel();
      final done = <String>[];

      watch<int>('a', () async => 1)
          .listen((_) {}, onDone: () => done.add('a'));
      watch<int>('b', () async => 1, channelToUse: otherChannel)
          .listen((_) {}, onDone: () => done.add('b'));

      await streams.dispose();

      verify(channel.unsubscribe).called(1);
      verify(otherChannel.unsubscribe).called(1);
      expect(done, unorderedEquals(['a', 'b']));
    });

    test('does not abort when a listener cancels while channels unsubscribe',
        () async {
      final unsubscribed = Completer<String>();
      when(channel.unsubscribe).thenAnswer((_) => unsubscribed.future);

      final sub = watch<int>('k', () async => 1).listen((_) {});

      final disposing = streams.dispose();
      await sub.cancel();
      unsubscribed.complete('ok');

      await expectLater(disposing, completes);
    });

    test('a failing unsubscribe does not prevent the others nor the closes',
        () async {
      final otherChannel = newChannel();
      when(channel.unsubscribe).thenAnswer((_) async => throw Exception('x'));
      var done = 0;

      watch<int>('a', () async => 1).listen((_) {}, onDone: () => done++);
      watch<int>('b', () async => 1, channelToUse: otherChannel)
          .listen((_) {}, onDone: () => done++);
      await pumpEventQueue();

      await expectLater(streams.dispose(), throwsException);
      await pumpEventQueue();

      verify(otherChannel.unsubscribe).called(1);
      expect(done, 2);
    });

    test('a watch started while disposing keeps its own controller', () async {
      Stream<int>? newStream;
      watch<int>('k', () async => 1).listen(
        (_) {},
        onDone: () => newStream = watch<int>('k', () async => 2),
      );

      await streams.dispose();
      await pumpEventQueue();

      var isDone = false;
      final received = <int>[];
      newStream!.listen(received.add, onDone: () => isDone = true);
      await pumpEventQueue();

      expect(isDone, isFalse);
      expect(received, [2]);
    });
  });
}
