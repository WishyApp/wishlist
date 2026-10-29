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
  final minimums = <String, Object?>{};

  void complete(PostgrestList rows) => _result.complete(rows);

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    filters[column] = value;
    return this;
  }

  @override
  PostgrestFilterBuilder<PostgrestList> gte(String column, Object value) {
    minimums[column] = value;
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

  group('getRecentlyAcceptedRequests', () {
    final since = DateTime.utc(2026, 10, 23, 8);

    test('asks for the accepted requests the user sent since a date', () async {
      final query = FakeQuery()
        ..complete([
          {
            'receiver_id': 'friend-1',
            'updated_at': '2026-10-28T09:30:00+00:00',
          },
          {'receiver_id': 'friend-2', 'updated_at': '2026-10-29T18:00:00Z'},
        ]);
      when(() => table.select(any())).thenAnswer((_) => query);
      final repository = SupabaseFriendshipRepository(client);

      final accepted = await repository.getRecentlyAcceptedRequests(since);

      expect(query.filters, {
        'requester_id': 'user-1',
        'status': 'accepted',
      });
      expect(query.minimums, {'updated_at': '2026-10-23T08:00:00.000Z'});
      expect(accepted, [
        (friendId: 'friend-1', acceptedAt: DateTime.utc(2026, 10, 28, 9, 30)),
        (friendId: 'friend-2', acceptedAt: DateTime.utc(2026, 10, 29, 18)),
      ]);
    });

    test('sends the date as UTC whatever the zone it comes in', () async {
      final query = FakeQuery()..complete(const []);
      when(() => table.select(any())).thenAnswer((_) => query);
      final repository = SupabaseFriendshipRepository(client);

      await repository.getRecentlyAcceptedRequests(
        DateTime.parse('2026-10-23T10:00:00+02:00'),
      );

      expect(query.minimums['updated_at'], '2026-10-23T08:00:00.000Z');
    });

    test('keeps the user it started with when the session changes', () async {
      final query = FakeQuery();
      when(() => table.select(any())).thenAnswer((_) => query);
      final repository = SupabaseFriendshipRepository(client);

      final request = repository.getRecentlyAcceptedRequests(since);
      currentUser = userWithId('user-2');
      query.complete(const []);
      await request;

      expect(query.filters['requester_id'], 'user-1');
    });
  });
}
