import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/home_card/supabase_home_card_repository.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

import '../../../../fixtures/mock_supabase.dart';

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Stands for `select()` and `order()`: the result is [rows].
// ignore: must_be_immutable
class FakeQuery extends Fake
    implements
        PostgrestFilterBuilder<PostgrestList>,
        PostgrestTransformBuilder<PostgrestList> {
  FakeQuery(this.rows);
  final PostgrestList rows;
  String? orderedBy;

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    orderedBy = column;
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) =>
      Future.value(rows).then(onValue, onError: onError);
}

Map<String, dynamic> _row(String key, {String kind = 'computed'}) => {
      'key': key,
      'kind': kind,
      'enabled': true,
      'priority': 10,
      'params': <String, dynamic>{},
    };

void main() {
  late MockSupabaseClient client;
  late MockQueryBuilder table;

  setUp(() {
    client = MockSupabaseClient();
    table = MockQueryBuilder();
    when(() => client.from('home_cards')).thenAnswer((_) => table);
  });

  test('returns the cards ordered by priority', () async {
    final query =
        FakeQuery([_row('christmas'), _row('home_stack', kind: 'settings')]);
    when(() => table.select()).thenAnswer((_) => query);

    final cards = await SupabaseHomeCardRepository(client).getActiveCards();

    expect(cards.map((c) => c.key), ['christmas', 'home_stack']);
    expect(cards.last.kind, HomeCardKind.settings);
    expect(query.orderedBy, 'priority');
  });

  test('skips a malformed row and keeps the valid ones', () async {
    final query = FakeQuery([
      _row('good'),
      {..._row('bad'), 'title': <String>[]},
      _row('unknown_kind', kind: 'banner'),
      {..._row('bad_params'), 'params': '[]'},
    ]);
    when(() => table.select()).thenAnswer((_) => query);

    final cards = await SupabaseHomeCardRepository(client).getActiveCards();

    expect(cards.map((c) => c.key), ['good']);
  });
}
