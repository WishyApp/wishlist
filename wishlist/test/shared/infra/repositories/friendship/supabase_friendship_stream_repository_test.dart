import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/friendship/supabase_friendship_stream_repository.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/mock_supabase.dart';

void main() {
  setUpAll(() => registerFallbackValue(PostgresChangeEvent.all));

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

    when(() => client.channel(any())).thenReturn(channel);
    when(
      () => channel.onPostgresChanges(
        event: any(named: 'event'),
        schema: any(named: 'schema'),
        table: any(named: 'table'),
        callback: any(named: 'callback'),
      ),
    ).thenReturn(channel);
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
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn(fakeCurrentUserId);
      when(() => auth.currentUser).thenReturn(mockUser);

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
