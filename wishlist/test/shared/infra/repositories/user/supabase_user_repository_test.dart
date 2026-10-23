import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/user/supabase_user_repository.dart';
import 'package:wishlist/shared/models/birthday.dart';

import '../../../../fixtures/mock_supabase.dart';

void main() {
  group('getCurrentUserEmail', () {
    test('is null, without throwing, when nobody is signed in', () {
      final session = FakeAuthSession();
      addTearDown(session.close);

      final repository = SupabaseUserRepository(session.client);

      expect(repository.getCurrentUserEmail(), isNull);
    });

    test('is the email of the signed-in user', () {
      final session = FakeAuthSession(userId: 'user-a', email: 'a@x.fr');
      addTearDown(session.close);

      expect(
        SupabaseUserRepository(session.client).getCurrentUserEmail(),
        'a@x.fr',
      );
    });

    test('is null when the signed-in account has no email', () {
      final session = FakeAuthSession(userId: 'user-a');
      addTearDown(session.close);

      final repository = SupabaseUserRepository(session.client);

      expect(repository.getCurrentUserEmail(), isNull);
    });
  });

  group('getVisibleBirthdays', () {
    test('skips a malformed row without dropping the others', () async {
      final session = FakeAuthSession(userId: 'user-a');
      addTearDown(session.close);
      final table = _MockQueryBuilder();
      when(() => session.client.from('profile_birthdays'))
          .thenAnswer((_) => table);
      final rows = _FakeRows([
        {'profile_id': 'a', 'month': 3, 'day': 12},
        {'profile_id': 'b', 'month': 4, 'day': 31},
        {'profile_id': 'c', 'month': 'x', 'day': 1},
        {'profile_id': 'd', 'month': 13, 'day': 1},
        {'profile_id': null, 'month': 1, 'day': 1},
        {'profile_id': 'e', 'month': 2, 'day': 29},
      ]);
      when(() => table.select('profile_id, month, day'))
          .thenAnswer((_) => rows);

      final birthdays = await SupabaseUserRepository(session.client)
          .getVisibleBirthdays({'a', 'b', 'c', 'd', 'e'}.toISet());

      expect(birthdays, {
        'a': const Birthday(month: 3, day: 12),
        'e': const Birthday(month: 2, day: 29),
      });
      // Only the friends' rows are asked for
      expect(rows.filteredColumn, 'profile_id');
      expect(rows.filteredValues, unorderedEquals(['a', 'b', 'c', 'd', 'e']));
    });

    test('does not query anything without friends', () async {
      final session = FakeAuthSession(userId: 'user-a');
      addTearDown(session.close);

      final birthdays = await SupabaseUserRepository(session.client)
          .getVisibleBirthdays(const ISetConst({}));

      expect(birthdays, isEmpty);
      verifyNever(() => session.client.from(any()));
    });
  });
}

class _MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

// ignore: must_be_immutable
class _FakeRows extends Fake implements PostgrestFilterBuilder<PostgrestList> {
  _FakeRows(this._rows);
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
