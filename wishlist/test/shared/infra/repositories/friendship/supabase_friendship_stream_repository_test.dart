import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/friendship/supabase_friendship_stream_repository.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/mock_supabase.dart';

class MockPostgresChangePayload extends Mock
    // ignore: avoid_implementing_value_types
    implements PostgresChangePayload {}

void main() {
  setUpAll(() => registerFallbackValue(PostgresChangeEvent.all));

  /// Listeners registered on the mock channel, in order.
  late List<_Listener> listeners;

  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late MockFriendshipRepository friendshipRepository;
  late MockRealtimeChannel channel;
  late SupabaseFriendshipStreamRepository repository;

  setUp(() {
    client = createMockSupabaseClient();
    auth = client.auth as MockGoTrueClient;
    friendshipRepository = MockFriendshipRepository();
    channel = MockRealtimeChannel();

    listeners = [];
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
      listeners.add(
        _Listener(
          event: invocation.namedArguments[#event] as PostgresChangeEvent,
          filter: invocation.namedArguments[#filter] as PostgresChangeFilter?,
          callback: invocation.namedArguments[#callback]
              as void Function(PostgresChangePayload),
        ),
      );
      return channel;
    });
    when(channel.subscribe).thenReturn(channel);
    when(channel.unsubscribe).thenAnswer((_) async => 'ok');

    when(() => friendshipRepository.getFriendsIds(any()))
        .thenAnswer((_) async => const ISet.empty());
    when(friendshipRepository.getCurrentUserPendingFriendsIds)
        .thenAnswer((_) async => const ISet.empty());
    when(friendshipRepository.getCurrentUserRequestedFriendsIds)
        .thenAnswer((_) async => const ISet.empty());

    repository =
        SupabaseFriendshipStreamRepository(client, friendshipRepository);
  });

  tearDown(() => repository.dispose());

  void signInAs(String userId) {
    final user = MockUser();
    when(() => user.id).thenReturn(userId);
    when(() => auth.currentUser).thenReturn(user);
  }

  group('realtime filters', () {
    setUp(() => signInAs('me'));

    void expectFiltered(Set<String> columns) {
      final filtered = listeners.where((l) => l.filter != null).toList();
      for (final l in filtered) {
        expect(l.filter!.type, PostgresChangeFilterType.eq);
        expect(l.filter!.value, 'me');
      }
      expect({for (final l in filtered) l.filter!.column}, columns);
      expect(filtered, hasLength(columns.length));

      // DELETE events cannot be filtered by Realtime: one unfiltered listener.
      final deletes =
          listeners.where((l) => l.event == PostgresChangeEvent.delete);
      expect(deletes, hasLength(1));
      expect(deletes.single.filter, isNull);
    }

    test('all friendships listens to both user columns of the current user',
        () async {
      final sub = repository.watchCurrentUserAllFriendships().listen((_) {});
      expectFiltered({'requester_id', 'receiver_id'});
      await sub.cancel();
    });

    test('friends of a user listen to both user columns', () async {
      final sub = repository.watchFriendsIds('me').listen((_) {});
      expectFiltered({'requester_id', 'receiver_id'});
      await sub.cancel();
    });

    test('pending (sent requests) listens to requester_id only', () async {
      final sub = repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      expectFiltered({'requester_id'});
      await sub.cancel();
    });

    test('requested (received requests) listens to receiver_id only',
        () async {
      final sub =
          repository.watchCurrentUserRequestedFriendsIds().listen((_) {});
      expectFiltered({'receiver_id'});
      await sub.cancel();
    });

    test('each listener, including delete, triggers a reload', () async {
      final received = <FriendshipIds>[];
      final sub =
          repository.watchCurrentUserAllFriendships().listen(received.add);
      await pumpEventQueue();
      expect(received, hasLength(1));

      final payload = MockPostgresChangePayload();
      for (final l in List.of(listeners)) {
        l.callback(payload);
        await pumpEventQueue();
      }

      // 2 filtered listeners + 1 delete listener, one reload each.
      expect(listeners, hasLength(3));
      expect(received, hasLength(1 + listeners.length));
      await sub.cancel();
    });
  });

  group('watchCurrentUserAllFriendships cleanup', () {
    test('unsubscribes and drops the controller after the session is closed',
        () async {
      final firstStream = repository.watchCurrentUserAllFriendships();
      final subscription = firstStream.listen((_) {});

      // Simulate logout: auth state is gone when onCancel fires.
      when(() => auth.currentUser).thenReturn(null);

      await subscription.cancel();

      verify(channel.unsubscribe).called(1);

      // Log back in: a new watch must not return the dead controller.
      signInAs(fakeCurrentUserId);

      final secondStream = repository.watchCurrentUserAllFriendships();
      await expectLater(secondStream.first, completes);
    });
  });

  group('dispose', () {
    test(
        'ends the per-key and the all friendships streams that still have '
        'listeners', () async {
      final allDone = Completer<void>();
      final pendingDone = Completer<void>();

      repository.watchCurrentUserAllFriendships().listen(
            (_) {},
            onDone: allDone.complete,
          );
      repository.watchCurrentUserPendingFriendsIds().listen(
            (_) {},
            onDone: pendingDone.complete,
          );

      await repository.dispose();

      await expectLater(allDone.future, completes);
      await expectLater(pendingDone.future, completes);
    });

    test('does not abort when a listener cancels while channels unsubscribe',
        () async {
      final unsubscribed = Completer<String>();
      when(channel.unsubscribe).thenAnswer((_) => unsubscribed.future);

      final subscription =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});

      final disposing = repository.dispose();
      await subscription.cancel();
      unsubscribed.complete('ok');

      await expectLater(disposing, completes);
    });

    test('a watch started while disposing keeps its own controller', () async {
      Stream<ISet<String>>? newStream;
      repository.watchCurrentUserPendingFriendsIds().listen(
            (_) {},
            onDone: () =>
                newStream = repository.watchCurrentUserPendingFriendsIds(),
          );

      await repository.dispose();
      await pumpEventQueue();

      var isDone = false;
      newStream!.listen((_) {}, onDone: () => isDone = true);
      await pumpEventQueue();

      expect(isDone, isFalse);
    });
  });

  group('watchCurrentUserAllFriendships user switch', () {
    test(
        'returns the data of the new user, not the cached controller of the '
        'previous one', () async {
      signInAs('user-a');
      when(() => friendshipRepository.getFriendsIds('user-a'))
          .thenAnswer((_) async => {'friend-of-a'}.lock);
      when(() => friendshipRepository.getFriendsIds('user-b'))
          .thenAnswer((_) async => {'friend-of-b'}.lock);

      // The listener of A stays mounted: onCancel never fires.
      repository.watchCurrentUserAllFriendships().listen((_) {});

      signInAs('user-b');
      final ids = await repository.watchCurrentUserAllFriendships().first;

      expect(ids.friendsIds, {'friend-of-b'}.lock);
    });

    test('a stale load of A does not write into the controller of B', () async {
      signInAs('user-a');
      final loadOfA = Completer<ISet<String>>();
      when(() => friendshipRepository.getFriendsIds('user-a'))
          .thenAnswer((_) => loadOfA.future);
      when(() => friendshipRepository.getFriendsIds('user-b'))
          .thenAnswer((_) async => {'friend-of-b'}.lock);

      final subscriptionA =
          repository.watchCurrentUserAllFriendships().listen((_) {});
      await subscriptionA.cancel();

      signInAs('user-b');
      final received = <FriendshipIds>[];
      final subscriptionB =
          repository.watchCurrentUserAllFriendships().listen(received.add);
      await pumpEventQueue();

      loadOfA.complete({'friend-of-a'}.lock);
      await pumpEventQueue();
      await subscriptionB.cancel();

      expect(received, hasLength(1));
      expect(received.single.friendsIds, {'friend-of-b'}.lock);
    });
  });
}

class _Listener {
  _Listener({
    required this.event,
    required this.filter,
    required this.callback,
  });

  final PostgresChangeEvent event;
  final PostgresChangeFilter? filter;
  final void Function(PostgresChangePayload) callback;
}
