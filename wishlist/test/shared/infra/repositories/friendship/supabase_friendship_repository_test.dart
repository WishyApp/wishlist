import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/friendship/supabase_friendship_repository.dart';
import 'package:wishlist/shared/models/friendship/friendship.dart';

import '../../../../fixtures/mock_supabase.dart';

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// A query whose result is only delivered when [complete] is called, and that
/// records the filters it receives.
class FakeQuery extends Fake implements PostgrestFilterBuilder<PostgrestList> {
  final _result = Completer<PostgrestList>();
  final filters = <String, Object?>{};

  void complete(PostgrestList rows) => _result.complete(rows);

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    filters[column] = value;
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) =>
      _result.future.then(onValue, onError: onError);
}

void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late MockQueryBuilder table;
  late User? currentUser;

  User userWithId(String id) {
    final user = MockUser();
    when(() => user.id).thenReturn(id);
    return user;
  }

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    table = MockQueryBuilder();
    currentUser = userWithId('user-1');
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenAnswer((_) => currentUser);
    when(() => client.from('friendships')).thenAnswer((_) => table);
  });

  test('currentUserId follows the session after an account switch', () {
    final repository = SupabaseFriendshipRepository(client);
    expect(repository.currentUserId, 'user-1');

    currentUser = userWithId('user-2');
    expect(repository.currentUserId, 'user-2');
  });

  test(
    'getCurrentUserPendingFriendsIds keeps the user it started with when the '
    'session changes during the request',
    () async {
      final query = FakeQuery();
      when(() => table.select()).thenAnswer((_) => query);
      final repository = SupabaseFriendshipRepository(client);

      final pending = repository.getCurrentUserPendingFriendsIds();
      currentUser = userWithId('user-2');
      query.complete([
        {
          'status': 'pending',
          'requester_id': 'user-1',
          'receiver_id': 'friend',
        },
      ]);

      expect(query.filters['requester_id'], 'user-1');
      expect((await pending).unlock, {'friend'});
    },
  );

  test(
    'getCurrentUserRequestedFriendsIds keeps the user it started with when '
    'the session changes during the request',
    () async {
      final query = FakeQuery();
      when(() => table.select()).thenAnswer((_) => query);
      final repository = SupabaseFriendshipRepository(client);

      final requested = repository.getCurrentUserRequestedFriendsIds();
      currentUser = userWithId('user-2');
      query.complete([
        {
          'status': 'pending',
          'requester_id': 'friend',
          'receiver_id': 'user-1',
        },
      ]);

      expect(query.filters['receiver_id'], 'user-1');
      expect((await requested).unlock, {'friend'});
    },
  );

  test(
    'askFriendshipTo inserts the request for the user it checked duplicates '
    'for when the session changes during the check',
    () async {
      final duplicateCheck = FakeQuery();
      final insert = FakeQuery()..complete(const []);
      when(() => table.select()).thenAnswer((_) => duplicateCheck);
      when(() => table.insert(any())).thenAnswer((_) => insert);
      final repository = SupabaseFriendshipRepository(client);

      final request = repository.askFriendshipTo('friend');
      currentUser = userWithId('user-2');
      duplicateCheck.complete(const []);
      await request;

      final inserted = verify(() => table.insert(captureAny())).captured.single
          as Friendship;
      expect(inserted.requesterId, 'user-1');
    },
  );
}
