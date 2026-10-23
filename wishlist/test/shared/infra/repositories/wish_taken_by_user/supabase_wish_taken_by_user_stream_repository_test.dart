import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/wish_taken_by_user/supabase_wish_taken_by_user_stream_repository.dart';
import 'package:wishlist/shared/models/wish_taken_by_user/wish_taken_by_user.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/mock_supabase.dart';

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

// ignore: avoid_implementing_value_types
class MockPostgresChangePayload extends Mock implements PostgresChangePayload {}

/// Requête `select().eq().order()` : chaque `order` retourne le résultat
/// suivant de [results], et `eq` enregistre la colonne et la valeur filtrées.
// ignore: must_be_immutable
class FakeTakenQuery extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  FakeTakenQuery(this.results);

  final List<Completer<PostgrestList>> results;
  int calls = 0;
  String? column;
  Object? value;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    this.column = column;
    this.value = value;
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      _FakeOrdered(results[calls++].future);
}

class _FakeOrdered extends Fake
    implements PostgrestTransformBuilder<PostgrestList> {
  _FakeOrdered(this._result);

  final Future<PostgrestList> _result;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) =>
      _result.then(onValue, onError: onError);
}

typedef _PayloadCallback = void Function(PostgresChangePayload);
typedef _StatusCallback = void Function(RealtimeSubscribeStatus, Object?);

Map<String, dynamic> _row(int quantity) => {
      'wish_id': 3,
      'user_id': fakeFriendUserId1,
      'quantity': quantity,
      'created_at': fakeCreatedAt.toIso8601String(),
      'updated_at': fakeUpdatedAt.toIso8601String(),
    };

void main() {
  setUpAll(() => registerFallbackValue(PostgresChangeEvent.all));

  late MockSupabaseClient client;
  late MockRealtimeChannel channel;
  late MockQueryBuilder table;
  late FakeTakenQuery query;
  late List<_PayloadCallback> callbacks;
  late List<PostgresChangeFilter?> filters;
  late List<_StatusCallback> statusCallbacks;
  late SupabaseWishTakenByUserStreamRepository repository;

  List<Completer<PostgrestList>> stubLoads(int count) {
    final loads = List.generate(count, (_) => Completer<PostgrestList>());
    query = FakeTakenQuery(loads);
    return loads;
  }

  setUp(() {
    client = createMockSupabaseClient();
    channel = MockRealtimeChannel();
    table = MockQueryBuilder();
    callbacks = [];
    filters = [];
    statusCallbacks = [];

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
      callbacks.add(invocation.namedArguments[#callback] as _PayloadCallback);
      filters.add(invocation.namedArguments[#filter] as PostgresChangeFilter?);
      return channel;
    });
    when(() => channel.subscribe(any())).thenAnswer((invocation) {
      statusCallbacks.add(
        invocation.positionalArguments.first as _StatusCallback,
      );
      return channel;
    });
    when(channel.unsubscribe).thenAnswer((_) async => 'ok');
    when(() => client.from('wish_taken_by_user')).thenAnswer((_) => table);
    when(table.select).thenAnswer((_) => query);

    repository = SupabaseWishTakenByUserStreamRepository(client);
  });

  tearDown(() => repository.dispose());

  group('watchTakenByUsersForWish', () {
    test('loads the bookings of the wish and filters the channel on it',
        () async {
      final loads = stubLoads(1);

      final received = <IList<WishTakenByUser>>[];
      final sub = repository.watchTakenByUsersForWish(3).listen(received.add);
      loads[0].complete([_row(2)]);
      await pumpEventQueue();

      expect(query.column, 'wish_id');
      expect(query.value, 3);
      expect(received.single.single.quantity, 2);
      verify(() => client.channel('wish_taken_by_user_wish_3')).called(1);
      expect(filters.single?.column, 'wish_id');
      expect(filters.single?.value, 3);
      await sub.cancel();
    });

    test('reloads on a realtime change and on every subscribed', () async {
      final loads = stubLoads(3);

      final received = <int>[];
      final sub = repository
          .watchTakenByUsersForWish(3)
          .listen((v) => received.add(v.single.quantity));
      loads[0].complete([_row(1)]);
      await pumpEventQueue();

      callbacks.single(MockPostgresChangePayload());
      loads[1].complete([_row(2)]);
      await pumpEventQueue();

      statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
      loads[2].complete([_row(3)]);
      await pumpEventQueue();

      expect(received, [1, 2, 3]);
      await sub.cancel();
    });

    test('a late subscriber gets the last value, with one load and one channel',
        () async {
      final loads = stubLoads(1);

      final first = <IList<WishTakenByUser>>[];
      final firstSub = repository.watchTakenByUsersForWish(3).listen(first.add);
      loads[0].complete([_row(1)]);
      await pumpEventQueue();

      final late = <IList<WishTakenByUser>>[];
      final lateSub = repository.watchTakenByUsersForWish(3).listen(late.add);
      await pumpEventQueue();

      expect(late.single.single.quantity, 1);
      expect(query.calls, 1);
      verify(() => client.channel(any())).called(1);

      await firstSub.cancel();
      verifyNever(channel.unsubscribe);
      await lateSub.cancel();
      verify(channel.unsubscribe).called(1);
    });

    test('a failing load is emitted as a stream error', () async {
      final loads = stubLoads(1);

      final errors = <Object>[];
      final sub = repository
          .watchTakenByUsersForWish(3)
          .listen((_) {}, onError: errors.add);
      loads[0].completeError(Exception('boom'));
      await pumpEventQueue();

      expect(errors, hasLength(1));
      await sub.cancel();
    });
  });

  group('watchTakenByUser', () {
    test('loads the bookings of the user and filters the channel on it',
        () async {
      final loads = stubLoads(1);

      final received = <IList<WishTakenByUser>>[];
      final sub = repository.watchTakenByUser('me').listen(received.add);
      loads[0].complete([_row(4)]);
      await pumpEventQueue();

      expect(query.column, 'user_id');
      expect(query.value, 'me');
      expect(received.single.single.quantity, 4);
      verify(() => client.channel('wish_taken_by_user_user_me')).called(1);
      expect(filters.single?.column, 'user_id');
      await sub.cancel();
    });

    test('reloads when the channel reports subscribed', () async {
      final loads = stubLoads(2);

      final received = <int>[];
      final sub = repository
          .watchTakenByUser('me')
          .listen((v) => received.add(v.single.quantity));
      loads[0].complete([_row(1)]);
      await pumpEventQueue();

      statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
      loads[1].complete([_row(2)]);
      await pumpEventQueue();

      expect(received, [1, 2]);
      await sub.cancel();
    });
  });
}
