import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/card_state/supabase_card_state_repository.dart';

import '../../../../fixtures/mock_supabase.dart';

/// An rpc call that succeeds without a result.
class FakeVoidRpc extends Fake implements PostgrestFilterBuilder<void> {
  @override
  Future<R> then<R>(
    FutureOr<R> Function(void value) onValue, {
    Function? onError,
  }) =>
      Future<void>.value().then(onValue, onError: onError);
}

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// A select that returns [_rows] and records its `inFilter`.
// ignore: must_be_immutable
class FakeRows extends Fake implements PostgrestFilterBuilder<PostgrestList> {
  FakeRows(this._rows);
  final PostgrestList _rows;
  String? filteredColumn;
  List<dynamic>? filteredValues;

  @override
  PostgrestFilterBuilder<PostgrestList> inFilter(String column, List values) {
    filteredColumn = column;
    filteredValues = values;
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) =>
      Future.value(_rows).then(onValue, onError: onError);
}

void main() {
  late MockSupabaseClient client;
  late SupabaseCardStateRepository repository;

  setUp(() {
    client = MockSupabaseClient();
    repository = SupabaseCardStateRepository(client);
    when(
      () => client.rpc<void>(any(), params: any(named: 'params')),
    ).thenAnswer((_) => FakeVoidRpc());
  });

  test('dismiss sends the snooze date in UTC', () async {
    final snoozeUntil = DateTime(2026, 12, 29, 8);

    await repository.dismiss('stale_wishlist:9', snoozeUntil: snoozeUntil);

    final params = verify(
      () => client.rpc<void>(
        'dismiss_card',
        params: captureAny(named: 'params'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(params['p_card_key'], 'stale_wishlist:9');
    final sent = params['p_snooze_until'] as String;
    expect(sent, endsWith('Z'));
    expect(DateTime.parse(sent).isAtSameMomentAs(snoozeUntil), isTrue);
  });

  group('getStates', () {
    test('asks for the given keys only and indexes the rows by key', () async {
      final table = MockQueryBuilder();
      final query = FakeRows([
        {
          'user_id': 'user-1',
          'card_key': 'stale_wishlist:9',
          'shown_count': 2,
          'last_shown_at': null,
          'dismissed_at': '2026-10-30T11:00:00+00:00',
          'snoozed_until': null,
        },
      ]);
      when(() => client.from('user_card_states')).thenAnswer((_) => table);
      when(table.select).thenAnswer((_) => query);

      final states =
          await repository.getStates(['stale_wishlist:9', 'booked_reminder:1']);

      expect(query.filteredColumn, 'card_key');
      expect(query.filteredValues, ['stale_wishlist:9', 'booked_reminder:1']);
      expect(states.keys, ['stale_wishlist:9']);
      expect(states['stale_wishlist:9']!.shownCount, 2);
    });

    test('makes no request for an empty list', () async {
      final states = await repository.getStates(const []);

      expect(states, isEmpty);
      verifyNever(() => client.from(any()));
    });
  });

  test('dismiss without a snooze sends null', () async {
    await repository.dismiss('booked_reminder:1');

    verify(
      () => client.rpc<void>(
        'dismiss_card',
        params: {'p_card_key': 'booked_reminder:1', 'p_snooze_until': null},
      ),
    ).called(1);
  });

  test('recordShown calls record_card_shown', () async {
    await repository.recordShown('christmas:2026');

    verify(
      () => client.rpc<void>(
        'record_card_shown',
        params: {'p_card_key': 'christmas:2026'},
      ),
    ).called(1);
  });
}
