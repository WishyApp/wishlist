import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/user/supabase_user_stream_repository.dart';
import 'package:wishlist/shared/models/profile.dart';

import '../../../../fixtures/mock_supabase.dart';

// ignore: avoid_implementing_value_types
class MockPostgresChangePayload extends Mock implements PostgresChangePayload {}

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Requête `select().eq().maybeSingle()` dont chaque résultat est délivré à la
/// demande : les appels à `maybeSingle` retournent les [Completer] dans
/// l'ordre.
// ignore: must_be_immutable
class FakeProfileQuery extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  FakeProfileQuery(this._loads);

  final List<Completer<PostgrestMap?>> _loads;
  int calls = 0;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() =>
      _FakeMaybeSingle(_loads[calls++].future);
}

class _FakeMaybeSingle extends Fake
    implements PostgrestTransformBuilder<PostgrestMap?> {
  _FakeMaybeSingle(this._result);

  final Future<PostgrestMap?> _result;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestMap? value) onValue, {
    Function? onError,
  }) =>
      _result.then(onValue, onError: onError);
}

typedef _PayloadCallback = void Function(PostgresChangePayload);
typedef _StatusCallback = void Function(RealtimeSubscribeStatus, Object?);

PostgrestMap _row(String pseudo) => {'id': 'me', 'pseudo': pseudo};

void main() {
  setUpAll(() => registerFallbackValue(PostgresChangeEvent.all));

  late MockSupabaseClient client;
  late MockRealtimeChannel channel;

  /// Status callbacks passed to `channel.subscribe`, in order.
  late List<_StatusCallback> statusCallbacks;
  late MockQueryBuilder table;
  late SupabaseUserStreamRepository repository;
  late List<_PayloadCallback> callbacks;
  late FakeProfileQuery query;

  /// Les chargements successifs retournent les [Completer] dans l'ordre.
  List<Completer<PostgrestMap?>> stubLoads(int count) {
    final loads = List.generate(count, (_) => Completer<PostgrestMap?>());
    query = FakeProfileQuery(loads);
    return loads;
  }

  /// Simule un changement realtime du profil.
  void triggerChange(
    Map<String, dynamic> newRecord, {
    PostgresChangeEvent event = PostgresChangeEvent.update,
  }) {
    final payload = MockPostgresChangePayload();
    when(() => payload.eventType).thenReturn(event);
    when(() => payload.newRecord).thenReturn(newRecord);
    callbacks.first(payload);
  }

  setUp(() {
    client = createMockSupabaseClient();
    channel = MockRealtimeChannel();
    statusCallbacks = [];
    table = MockQueryBuilder();
    callbacks = [];

    when(() => client.channel(any())).thenReturn(channel);
    when(
      () => channel.onPostgresChanges(
        event: any(named: 'event'),
        schema: any(named: 'schema'),
        table: any(named: 'table'),
        filter: any(named: 'filter'),
        callback: any(named: 'callback'),
      ),
    ).thenAnswer((invocation) {
      callbacks.add(
        invocation.namedArguments[#callback] as _PayloadCallback,
      );
      return channel;
    });
    when(() => channel.subscribe(any())).thenAnswer((invocation) {
      statusCallbacks.add(
        invocation.positionalArguments.first as _StatusCallback,
      );
      return channel;
    });
    when(channel.unsubscribe).thenAnswer((_) async => 'ok');
    when(() => client.from('profiles')).thenAnswer((_) => table);
    when(table.select).thenAnswer((_) => query);

    repository = SupabaseUserStreamRepository(client);
  });

  tearDown(() => repository.dispose());

  group('watchProfileById', () {
    test('reloads each time the channel reports subscribed', () async {
      final loads = stubLoads(3);

      final received = <Profile?>[];
      final sub = repository.watchProfileById('me').listen(received.add);
      loads[0].complete(_row('Alice'));
      await pumpEventQueue();

      expect(statusCallbacks, hasLength(1));
      statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
      loads[1].complete(_row('Bob'));
      await pumpEventQueue();

      statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
      loads[2].complete(_row('Carol'));
      await pumpEventQueue();

      expect(query.calls, 3);
      expect(received.map((p) => p?.pseudo), ['Alice', 'Bob', 'Carol']);
      await sub.cancel();
    });

    test('a second subscriber on the same user gets the current value',
        () async {
      final loads = stubLoads(1);

      final first = <Profile?>[];
      final firstSub = repository.watchProfileById('me').listen(first.add);
      loads[0].complete(_row('Alice'));
      await pumpEventQueue();
      expect(first.single?.pseudo, 'Alice');

      final second = <Profile?>[];
      final secondSub = repository.watchProfileById('me').listen(second.add);
      await pumpEventQueue();

      expect(second.single?.pseudo, 'Alice');
      // One load and one channel, shared by both subscribers.
      expect(query.calls, 1);
      verify(() => client.channel('profile_me')).called(1);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('a missing profile is replayed as null', () async {
      final loads = stubLoads(1);

      final firstSub = repository.watchProfileById('me').listen((_) {});
      loads[0].complete(null);
      await pumpEventQueue();

      final second = <Profile?>[];
      final secondSub = repository.watchProfileById('me').listen(second.add);
      await pumpEventQueue();

      expect(second, [null]);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('an error before any value triggers a reload without being replayed',
        () async {
      final loads = stubLoads(2);

      final firstSub =
          repository.watchProfileById('me').listen((_) {}, onError: (_) {});
      loads[0].completeError(Exception('boom'));
      await pumpEventQueue();

      final errors = <Object>[];
      final values = <Profile?>[];
      final secondSub = repository
          .watchProfileById('me')
          .listen(values.add, onError: errors.add);
      await pumpEventQueue();
      // The stale cached error is the one being retried: not replayed.
      expect(errors, isEmpty);
      // The new subscriber started a retry.
      expect(query.calls, 2);

      loads[1].complete(_row('Alice'));
      await pumpEventQueue();
      expect(errors, isEmpty);
      expect(values.single?.pseudo, 'Alice');

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('a retry that fails again emits the new error to the new subscriber',
        () async {
      final loads = stubLoads(2);

      final firstSub =
          repository.watchProfileById('me').listen((_) {}, onError: (_) {});
      loads[0].completeError(Exception('first'));
      await pumpEventQueue();

      final errors = <Object>[];
      final secondSub =
          repository.watchProfileById('me').listen((_) {}, onError: errors.add);
      await pumpEventQueue();
      expect(errors, isEmpty);

      loads[1].completeError(Exception('second'));
      await pumpEventQueue();
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('second'));

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('an error after a value keeps the value for live and late subscribers',
        () async {
      final loads = stubLoads(1);

      final live = <Profile?>[];
      final liveErrors = <Object>[];
      final firstSub = repository
          .watchProfileById('me')
          .listen(live.add, onError: liveErrors.add);
      loads[0].complete(_row('Alice'));
      await pumpEventQueue();

      // A payload that cannot be parsed fails the reload.
      triggerChange({'id': 'me'});
      await pumpEventQueue();

      final late = <Profile?>[];
      final lateErrors = <Object>[];
      final secondSub = repository
          .watchProfileById('me')
          .listen(late.add, onError: lateErrors.add);
      await pumpEventQueue();

      expect(liveErrors, isEmpty);
      expect(lateErrors, isEmpty);
      expect(live.single?.pseudo, 'Alice');
      expect(late.single?.pseudo, 'Alice');

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('a slow initial load does not overwrite a newer realtime change',
        () async {
      final loads = stubLoads(1);

      final live = <Profile?>[];
      final firstSub = repository.watchProfileById('me').listen(live.add);
      triggerChange(_row('Bob'));
      await pumpEventQueue();
      loads[0].complete(_row('Alice'));
      await pumpEventQueue();

      final late = <Profile?>[];
      final secondSub = repository.watchProfileById('me').listen(late.add);
      await pumpEventQueue();

      expect(live.map((p) => p?.pseudo), ['Bob']);
      expect(late.map((p) => p?.pseudo), ['Bob']);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('a deleted profile emits null', () async {
      final loads = stubLoads(1);

      final received = <Profile?>[];
      final sub = repository.watchProfileById('me').listen(received.add);
      loads[0].complete(_row('Alice'));
      await pumpEventQueue();

      triggerChange(_row('Alice'), event: PostgresChangeEvent.delete);
      await pumpEventQueue();

      expect(received.map((p) => p?.pseudo), ['Alice', null]);

      await sub.cancel();
    });

    test('keeps the channel until the last subscriber leaves', () async {
      final loads = stubLoads(1);
      loads[0].complete(_row('Alice'));

      final firstSub = repository.watchProfileById('me').listen((_) {});
      final secondSub = repository.watchProfileById('me').listen((_) {});
      await pumpEventQueue();

      await firstSub.cancel();
      verifyNever(channel.unsubscribe);

      await secondSub.cancel();
      verify(channel.unsubscribe).called(1);
    });

    test('a new subscriber after full cleanup reloads and gets the value',
        () async {
      final loads = stubLoads(2);
      loads[0].complete(_row('Alice'));

      final firstSub = repository.watchProfileById('me').listen((_) {});
      await pumpEventQueue();
      await firstSub.cancel();

      final received = <Profile?>[];
      final secondSub = repository.watchProfileById('me').listen(received.add);
      loads[1].complete(_row('Bob'));
      await pumpEventQueue();

      expect(received.single?.pseudo, 'Bob');
      expect(query.calls, 2);

      await secondSub.cancel();
    });
  });
}
