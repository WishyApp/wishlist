import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_repository.dart';
import 'package:wishlist/shared/infra/repositories/friendship/supabase_friendship_stream_repository.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/mock_supabase.dart';

class MockFriendshipRepository extends Mock implements FriendshipRepository {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

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
}
