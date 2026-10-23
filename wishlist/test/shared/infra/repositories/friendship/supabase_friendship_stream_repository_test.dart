import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/friendship/supabase_friendship_stream_repository.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/mock_supabase.dart';

// ignore: avoid_implementing_value_types
class MockPostgresChangePayload extends Mock implements PostgresChangePayload {}

void main() {
  setUpAll(() => registerFallbackValue(PostgresChangeEvent.all));

  /// Listeners registered on the mock channel, in order.
  late List<_Listener> listeners;

  /// Status callbacks passed to `channel.subscribe`, in order.
  late List<_StatusCallback> statusCallbacks;

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
      final callback = invocation.namedArguments[#callback] as _PayloadCallback;
      listeners.add(
        _Listener(
          event: invocation.namedArguments[#event] as PostgresChangeEvent,
          filter: invocation.namedArguments[#filter] as PostgresChangeFilter?,
          callback: callback,
        ),
      );
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
      // Every listener is filtered; `all` includes DELETEs. These tests only
      // check the channel configuration: that Realtime delivers filtered
      // DELETEs relies on REPLICA IDENTITY FULL, checked by
      // supabase-tests/friendships_realtime.sql.
      expect(listeners.where((l) => l.filter == null), isEmpty);
      final filtered = listeners;
      for (final l in filtered) {
        expect(l.event, PostgresChangeEvent.all);
        expect(l.filter!.type, PostgresChangeFilterType.eq);
        expect(l.filter!.value, 'me');
      }
      expect({for (final l in filtered) l.filter!.column}, columns);
      expect(filtered, hasLength(columns.length));
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

    test('requested (received requests) listens to receiver_id only', () async {
      final sub =
          repository.watchCurrentUserRequestedFriendsIds().listen((_) {});
      expectFiltered({'receiver_id'});
      await sub.cancel();
    });

    test('each listener triggers a reload', () async {
      final received = <FriendshipIds>[];
      final sub =
          repository.watchCurrentUserAllFriendships().listen(received.add);
      await pumpEventQueue();
      expect(received, hasLength(1));

      final payload = MockPostgresChangePayload();
      var reload = 0;
      for (final l in List.of(listeners)) {
        // Identical results are not re-emitted: make each reload differ.
        when(() => friendshipRepository.getFriendsIds(any()))
            .thenAnswer((_) async => {'friend-${reload++}'}.lock);
        l.callback(payload);
        await pumpEventQueue();
      }

      // 2 filtered listeners, one reload each.
      expect(listeners, hasLength(2));
      expect(received, hasLength(1 + listeners.length));
      await sub.cancel();
    });
  });

  group('replay to late subscribers', () {
    setUp(() {
      signInAs('me');
      when(() => friendshipRepository.getFriendsIds(any()))
          .thenAnswer((_) async => {'friend'}.lock);
      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) async => {'pending'}.lock);
      when(friendshipRepository.getCurrentUserRequestedFriendsIds)
          .thenAnswer((_) async => {'requested'}.lock);
    });

    test('all friendships replays the last value', () async {
      final first = repository.watchCurrentUserAllFriendships().listen((_) {});
      await pumpEventQueue();

      final ids = await repository
          .watchCurrentUserAllFriendships()
          .first
          .timeout(const Duration(seconds: 1));

      expect(ids.friendsIds, {'friend'}.lock);
      expect(ids.pendingIds, {'pending'}.lock);
      expect(ids.requestedIds, {'requested'}.lock);
      await first.cancel();
    });

    test('friends of a user replays the last value', () async {
      final first = repository.watchFriendsIds('u').listen((_) {});
      await pumpEventQueue();

      final ids = await repository
          .watchFriendsIds('u')
          .first
          .timeout(const Duration(seconds: 1));

      expect(ids, {'friend'}.lock);
      await first.cancel();
    });

    test('pending replays the last value', () async {
      final first =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      await pumpEventQueue();

      final ids = await repository
          .watchCurrentUserPendingFriendsIds()
          .first
          .timeout(const Duration(seconds: 1));

      expect(ids, {'pending'}.lock);
      await first.cancel();
    });

    test('requested replays the last value', () async {
      final first =
          repository.watchCurrentUserRequestedFriendsIds().listen((_) {});
      await pumpEventQueue();

      final ids = await repository
          .watchCurrentUserRequestedFriendsIds()
          .first
          .timeout(const Duration(seconds: 1));

      expect(ids, {'requested'}.lock);
      await first.cancel();
    });

    test('a late subscriber also receives the following updates', () async {
      final first =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      await pumpEventQueue();

      final received = <ISet<String>>[];
      final late =
          repository.watchCurrentUserPendingFriendsIds().listen(received.add);
      await pumpEventQueue();

      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) async => {'pending', 'new'}.lock);
      listeners.first.callback(MockPostgresChangePayload());
      await pumpEventQueue();

      expect(received, [
        {'pending'}.lock,
        {'pending', 'new'}.lock,
      ]);
      await first.cancel();
      await late.cancel();
    });

    test('keeps the channel until the last listener leaves', () async {
      final first =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      final second =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      await pumpEventQueue();

      await first.cancel();
      verifyNever(channel.unsubscribe);

      await second.cancel();
      verify(channel.unsubscribe).called(1);
    });

    test('keeps the channel until the last listener leaves, replayed one too',
        () async {
      final first =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      await pumpEventQueue();
      final replayed =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      await pumpEventQueue();

      await first.cancel();
      verifyNever(channel.unsubscribe);

      await replayed.cancel();
      verify(channel.unsubscribe).called(1);
    });

    test('a watch after the last listener left reloads from scratch', () async {
      final first =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      await pumpEventQueue();
      await first.cancel();

      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) async => {'other'}.lock);
      final ids = await repository
          .watchCurrentUserPendingFriendsIds()
          .first
          .timeout(const Duration(seconds: 1));

      expect(ids, {'other'}.lock);
    });
  });

  group('reload ordering', () {
    setUp(() => signInAs('me'));

    test('an older reload finishing last does not overwrite the newest value',
        () async {
      final slow = Completer<ISet<String>>();
      final fast = Completer<ISet<String>>();
      final queue = [slow, fast];
      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) => queue.removeAt(0).future);

      final first =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      // The initial load took `slow`; the event starts a newer reload, `fast`.
      listeners.first.callback(MockPostgresChangePayload());
      await pumpEventQueue();
      expect(queue, isEmpty);
      fast.complete({'new'}.lock);
      await pumpEventQueue();
      slow.complete({'stale'}.lock);
      await pumpEventQueue();

      final replayed = await repository
          .watchCurrentUserPendingFriendsIds()
          .first
          .timeout(const Duration(seconds: 1));
      expect(replayed, {'new'}.lock);
      await first.cancel();
    });

    test('an initial load finishing after the first event is ignored',
        () async {
      final initial = Completer<ISet<String>>();
      final queue = [initial];
      when(friendshipRepository.getCurrentUserRequestedFriendsIds).thenAnswer(
        (_) => queue.isNotEmpty
            ? queue.removeAt(0).future
            : Future.value({'after-event'}.lock),
      );

      final received = <ISet<String>>[];
      final sub =
          repository.watchCurrentUserRequestedFriendsIds().listen(received.add);
      listeners.first.callback(MockPostgresChangePayload());
      await pumpEventQueue();
      initial.complete({'stale'}.lock);
      await pumpEventQueue();

      expect(received, [
        {'after-event'}.lock,
      ]);
      await sub.cancel();
    });
  });

  group('errors', () {
    setUp(() => signInAs('me'));

    test('a failed reload keeps the last value for a late subscriber',
        () async {
      final errors = <Object>[];
      final first = repository
          .watchCurrentUserPendingFriendsIds()
          .listen((_) {}, onError: errors.add);
      await pumpEventQueue();

      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) async => throw Exception('offline'));
      listeners.first.callback(MockPostgresChangePayload());
      await pumpEventQueue();

      final replayed = await repository
          .watchCurrentUserPendingFriendsIds()
          .first
          .timeout(const Duration(seconds: 1));
      expect(replayed, const ISet<String>.empty());
      expect(errors, isEmpty);
      await first.cancel();
    });

    test('a failed first load is replayed with its stack trace', () async {
      final trace = StackTrace.current;
      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) => Future.error(Exception('offline'), trace));

      final first = repository
          .watchCurrentUserPendingFriendsIds()
          .listen((_) {}, onError: (_) {});
      await pumpEventQueue();

      Object? error;
      StackTrace? stackTrace;
      final late = repository.watchCurrentUserPendingFriendsIds().listen(
        (_) {},
        onError: (Object e, StackTrace st) {
          error = e;
          stackTrace = st;
        },
      );
      await pumpEventQueue();

      expect(error, isA<Exception>());
      expect(stackTrace, trace);
      await first.cancel();
      await late.cancel();
    });
  });

  group('reload once subscribed', () {
    setUp(() => signInAs('me'));

    test('reloads when the channel reports subscribed', () async {
      final received = <ISet<String>>[];
      final sub =
          repository.watchCurrentUserPendingFriendsIds().listen(received.add);
      await pumpEventQueue();
      expect(received, hasLength(1));

      // A change committed between the first query and the subscription is
      // not delivered as an event: the subscribed status triggers a reload.
      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) async => {'missed'}.lock);
      expect(statusCallbacks, hasLength(1));
      statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
      await pumpEventQueue();

      expect(received.last, {'missed'}.lock);
      await sub.cancel();
    });

    test('does not reload for a channel error', () async {
      final received = <ISet<String>>[];
      final sub =
          repository.watchCurrentUserPendingFriendsIds().listen(received.add);
      await pumpEventQueue();

      statusCallbacks.single(RealtimeSubscribeStatus.channelError, null);
      await pumpEventQueue();

      expect(received, hasLength(1));
      await sub.cancel();
    });
  });

  group('reload ordering edge cases', () {
    setUp(() => signInAs('me'));

    test('a first load still delivers its value when a later reload fails',
        () async {
      final initial = Completer<ISet<String>>();
      final reload = Completer<ISet<String>>();
      final queue = [initial, reload];
      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) => queue.removeAt(0).future);

      final received = <ISet<String>>[];
      final errors = <Object>[];
      final sub = repository
          .watchCurrentUserPendingFriendsIds()
          .listen(received.add, onError: errors.add);
      // The channel is subscribed while the initial query is still running.
      statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
      await pumpEventQueue();
      initial.complete({'valid'}.lock);
      await pumpEventQueue();
      reload.completeError(Exception('offline'));
      await pumpEventQueue();

      expect(received, [
        {'valid'}.lock,
      ]);
      expect(errors, isEmpty);
      await sub.cancel();
    });

    test('an older load failing while a newer one is pending emits no error',
        () async {
      final older = Completer<ISet<String>>();
      final newer = Completer<ISet<String>>();
      final queue = [older, newer];
      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) => queue.removeAt(0).future);

      final received = <ISet<String>>[];
      final errors = <Object>[];
      final sub = repository
          .watchCurrentUserPendingFriendsIds()
          .listen(received.add, onError: errors.add);
      listeners.first.callback(MockPostgresChangePayload());
      await pumpEventQueue();

      older.completeError(Exception('older failed'));
      await pumpEventQueue();
      newer.complete({'newer'}.lock);
      await pumpEventQueue();

      expect(errors, isEmpty);
      expect(received, [
        {'newer'}.lock,
      ]);
      await sub.cancel();
    });

    test('a late callback of a closed controller does not hide an error',
        () async {
      final first =
          repository.watchCurrentUserPendingFriendsIds().listen((_) {});
      await pumpEventQueue();
      final oldCallback = listeners.first.callback;
      final oldStatus = statusCallbacks.first;
      await first.cancel();

      final load = Completer<ISet<String>>();
      when(friendshipRepository.getCurrentUserPendingFriendsIds)
          .thenAnswer((_) => load.future);
      final errors = <Object>[];
      final second = repository
          .watchCurrentUserPendingFriendsIds()
          .listen((_) {}, onError: errors.add);

      // The old channel fires again (rejoin) after the cleanup: it must not
      // make the load of the new controller look outdated.
      oldCallback(MockPostgresChangePayload());
      oldStatus(RealtimeSubscribeStatus.subscribed, null);
      load.completeError(Exception('offline'));
      await pumpEventQueue();

      expect(errors, hasLength(1));
      await second.cancel();
    });
  });

  group('identical reloads', () {
    setUp(() => signInAs('me'));

    test('all friendships does not re-emit an identical value', () async {
      final received = <FriendshipIds>[];
      final sub =
          repository.watchCurrentUserAllFriendships().listen(received.add);
      await pumpEventQueue();
      // The channel reports subscribed: the reload returns the same data.
      statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
      await pumpEventQueue();
      expect(received, hasLength(1));

      when(() => friendshipRepository.getFriendsIds(any()))
          .thenAnswer((_) async => {'new'}.lock);
      listeners.first.callback(MockPostgresChangePayload());
      await pumpEventQueue();

      expect(received, hasLength(2));
      expect(received.last.friendsIds, {'new'}.lock);
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

typedef _PayloadCallback = void Function(PostgresChangePayload);
typedef _StatusCallback = void Function(RealtimeSubscribeStatus, Object?);

class _Listener {
  _Listener({
    required this.event,
    required this.filter,
    required this.callback,
  });

  final PostgresChangeEvent event;
  final PostgresChangeFilter? filter;
  final _PayloadCallback callback;
}
