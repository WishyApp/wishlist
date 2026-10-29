import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/supabase_booked_wish_removal_repository.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';

import '../../../../fixtures/mock_supabase.dart';

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

// ignore: avoid_implementing_value_types
class MockPostgresChangePayload extends Mock implements PostgresChangePayload {}

/// Query `select().isFilter().order()`: records the filter and the order, and
/// delivers the next of [results] on each `order`.
// ignore: must_be_immutable
class FakePendingQuery extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  FakePendingQuery(this.results);

  final List<PostgrestList> results;
  int calls = 0;
  String? nullColumn;
  Object? nullValue;
  String? orderColumn;
  bool? orderAscending;

  @override
  PostgrestFilterBuilder<PostgrestList> isFilter(String column, Object? value) {
    nullColumn = column;
    nullValue = value;
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    orderColumn = column;
    orderAscending = ascending;
    return _FakeOrdered(results[calls++]);
  }
}

class _FakeOrdered extends Fake
    implements PostgrestTransformBuilder<PostgrestList> {
  _FakeOrdered(this._result);

  final PostgrestList _result;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) =>
      Future.value(_result).then(onValue, onError: onError);
}

/// Result of `rpc()`: resolves with no value.
// ignore: must_be_immutable
class FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) =>
      Future<dynamic>.value().then(onValue, onError: onError);
}

typedef _PayloadCallback = void Function(PostgresChangePayload);
typedef _StatusCallback = void Function(RealtimeSubscribeStatus, Object?);

Map<String, dynamic> _row(int id, String removedAt) => {
      'id': id,
      'booker_id': 'me',
      'owner_id': 'owner',
      'owner_pseudo': 'Lea',
      'wish_id': 100 + id,
      'wish_name': 'Wish $id',
      'quantity': 1,
      'wishlist_name': 'List',
      'removed_at': removedAt,
      'dismissed_at': null,
    };

void main() {
  setUpAll(() => registerFallbackValue(PostgresChangeEvent.all));

  late MockSupabaseClient client;
  late MockRealtimeChannel channel;
  late MockQueryBuilder table;
  late List<_PayloadCallback> callbacks;
  late List<PostgresChangeFilter?> filters;
  late List<PostgresChangeEvent> events;
  late List<String> tables;
  late List<_StatusCallback> statusCallbacks;
  late SupabaseBookedWishRemovalRepository repository;

  setUp(() {
    client = createMockSupabaseClient(userId: 'me');
    channel = MockRealtimeChannel();
    table = MockQueryBuilder();
    callbacks = [];
    filters = [];
    events = [];
    tables = [];
    statusCallbacks = [];

    when(() => client.from('booked_wish_removals')).thenAnswer((_) => table);
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
      events.add(invocation.namedArguments[#event] as PostgresChangeEvent);
      tables.add(invocation.namedArguments[#table] as String);
      return channel;
    });
    when(() => channel.subscribe(any())).thenAnswer((invocation) {
      final callback = invocation.positionalArguments.first as _StatusCallback?;
      if (callback != null) {
        statusCallbacks.add(callback);
      }
      return channel;
    });
    when(channel.unsubscribe).thenAnswer((_) async => 'ok');

    repository = SupabaseBookedWishRemovalRepository(client);
  });

  tearDown(() => repository.dispose());

  group('watchPending', () {
    test('loads the pending alerts, not dismissed, most recent first',
        () async {
      final query = FakePendingQuery([
        [
          _row(2, '2026-10-30T10:00:00Z'),
          _row(1, '2026-10-29T10:00:00Z'),
        ],
      ]);
      when(table.select).thenAnswer((_) => query);

      final removals = await repository.watchPending().first;

      expect(removals.map((r) => r.id), [2, 1]);
      expect(removals.first, isA<BookedWishRemoval>());
      expect(query.nullColumn, 'dismissed_at');
      expect(query.nullValue, isNull);
      expect(query.orderColumn, 'removed_at');
      expect(query.orderAscending, isFalse);
    });

    test('listens to the rows booked by the current user', () async {
      when(table.select).thenAnswer((_) => FakePendingQuery([[], []]));

      final sub = repository.watchPending().listen((_) {});
      await pumpEventQueue();

      expect(filters, hasLength(1));
      expect(tables.single, 'booked_wish_removals');
      // `all`: an INSERT (new alert) and an UPDATE (dismissed on another
      // device) both reload. That Realtime applies the SELECT policy is
      // checked by the RLS tests (supabase-tests/booked_wish_removals.sql).
      expect(events.single, PostgresChangeEvent.all);
      expect(filters.single!.type, PostgresChangeFilterType.eq);
      expect(filters.single!.column, 'booker_id');
      expect(filters.single!.value, 'me');
      await sub.cancel();
    });

    test('an event reloads the list', () async {
      final query = FakePendingQuery([
        [_row(1, '2026-10-29T10:00:00Z')],
        [
          _row(2, '2026-10-30T10:00:00Z'),
          _row(1, '2026-10-29T10:00:00Z'),
        ],
      ]);
      when(table.select).thenAnswer((_) => query);

      final received = <List<BookedWishRemoval>>[];
      final sub = repository.watchPending().listen(received.add);
      await pumpEventQueue();
      expect(received.map((l) => l.length), [1]);

      callbacks.single(MockPostgresChangePayload());
      await pumpEventQueue();

      expect(received.map((l) => l.length), [1, 2]);
      await sub.cancel();
    });

    test('a subscribed status reloads the list', () async {
      final query = FakePendingQuery([
        [_row(1, '2026-10-29T10:00:00Z')],
        [
          _row(2, '2026-10-30T10:00:00Z'),
          _row(1, '2026-10-29T10:00:00Z'),
        ],
      ]);
      when(table.select).thenAnswer((_) => query);

      final received = <List<BookedWishRemoval>>[];
      final sub = repository.watchPending().listen(received.add);
      await pumpEventQueue();
      expect(received.map((l) => l.length), [1]);

      // A change committed before the subscription is never delivered as an
      // event: the first `subscribed` reloads.
      statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
      await pumpEventQueue();

      expect(received.map((l) => l.length), [1, 2]);
      await sub.cancel();
    });

    test('the load error is surfaced', () async {
      when(table.select).thenThrow(Exception('boom'));

      await expectLater(repository.watchPending().first, throwsException);
    });
  });

  group('dismiss', () {
    test('calls the server function with the id', () async {
      Map<String, dynamic>? params;
      when(
        () => client.rpc<dynamic>(
          'dismiss_booked_wish_removal',
          params: any(named: 'params'),
        ),
      ).thenAnswer((invocation) {
        params = invocation.namedArguments[#params] as Map<String, dynamic>?;
        return FakeRpc();
      });

      await repository.dismiss(42);

      expect(params, {'p_id': 42});
    });

    test('the stream drops the row without a realtime event', () async {
      final query = FakePendingQuery([
        [
          _row(2, '2026-10-30T10:00:00Z'),
          _row(1, '2026-10-29T10:00:00Z'),
        ],
        [_row(1, '2026-10-29T10:00:00Z')],
      ]);
      when(table.select).thenAnswer((_) => query);
      when(
        () => client.rpc<dynamic>(
          'dismiss_booked_wish_removal',
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) => FakeRpc());

      final received = <List<BookedWishRemoval>>[];
      final sub = repository.watchPending().listen(received.add);
      await pumpEventQueue();
      expect(received.last.map((r) => r.id), [2, 1]);

      await repository.dismiss(2);
      await pumpEventQueue();

      expect(received.last.map((r) => r.id), [1]);
      await sub.cancel();
    });
  });
}
