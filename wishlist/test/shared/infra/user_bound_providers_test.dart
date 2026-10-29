import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/current_user_profile_provider.dart';
import 'package:wishlist/shared/infra/friendship_service.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/received_wishes_summary_provider.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/user/user_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/user/user_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

import '../../fixtures/fake_data.dart';
import '../../fixtures/mock_supabase.dart';

class MockFriendshipStreamRepository extends Mock
    implements FriendshipStreamRepository {}

class MockWishlistStreamRepository extends Mock
    implements WishlistStreamRepository {}

class MockWishStreamRepository extends Mock implements WishStreamRepository {}

class MockUserStreamRepository extends Mock implements UserStreamRepository {}

class MockCompletedWishStreamRepository extends Mock
    implements UserCompletedWishStreamRepository {}

AppUser _appUserFor(String userId) => AppUser(
      profile: Profile(id: userId, pseudo: 'pseudo-$userId', avatarUrl: userId),
      user: fakeCurrentAppUser.user,
    );

final _completedWish = CompletedWishWithDetails(
  wish: fakeWish1,
  fromWishlistId: 1,
  fromWishlistName: 'w',
  ownerPseudo: 'Alice',
  ownerId: fakeFriendUserId1,
  completedAt: fakeCreatedAt,
  quantity: 1,
);

Wishlist _wishlistOf(String ownerId) => Wishlist(
      id: 1,
      createdAt: fakeCreatedAt,
      name: 'w',
      idOwner: ownerId,
      color: fakeColorBlue,
      canOwnerSeeTakenWish: true,
      order: 0,
      updatedBy: ownerId,
      updatedAt: fakeUpdatedAt,
    );

/// A user switch while the provider stays listened to: the situation of the
/// providers kept alive by a widget that survives logout then login (F015).
void main() {
  late FakeAuthSession session;
  late MockUserService userService;
  late ProviderContainer container;

  String? currentId() => session.auth.currentUser?.id;

  void start({String? userId, List<Override> overrides = const []}) {
    session = FakeAuthSession(userId: userId);
    addTearDown(session.close);
    userService = MockUserService();
    when(() => userService.getAppUserById(any())).thenAnswer(
      (i) async => _appUserFor(i.positionalArguments.first as String),
    );
    container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(session.client),
        userServiceProvider.overrideWithValue(userService),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
  }

  group('friendshipRepositoryProvider', () {
    test('is rebuilt on a user switch, with what depends on it', () async {
      start(userId: 'user-a');
      container
        ..listen(friendshipRepositoryProvider, (_, __) {})
        ..listen(friendshipServiceProvider, (_, __) {});
      final repository = container.read(friendshipRepositoryProvider);
      final service = container.read(friendshipServiceProvider);

      session.signIn('user-b');
      await pumpEventQueue();

      expect(container.read(friendshipRepositoryProvider), isNot(repository));
      expect(container.read(friendshipServiceProvider), isNot(service));
    });

    test('is kept on events that keep the same user', () async {
      start(userId: 'user-a');
      container.listen(friendshipRepositoryProvider, (_, __) {});
      final repository = container.read(friendshipRepositoryProvider);

      session.refreshToken();
      await pumpEventQueue();

      expect(container.read(friendshipRepositoryProvider), repository);
    });
  });

  group('friendshipsRealtimeProvider', () {
    late MockFriendshipStreamRepository repository;

    setUp(() {
      repository = MockFriendshipStreamRepository();
      // Like the real repository: reads the current user when called.
      when(repository.watchCurrentUserAllFriendships).thenAnswer(
        (_) => Stream.value(
          FriendshipIds(
            friendsIds: ISet({'friend-of-${currentId()}'}),
            pendingIds: const ISetConst({}),
            requestedIds: const ISetConst({}),
          ),
        ),
      );
    });

    List<String> friendIds() => container
        .read(friendshipsRealtimeProvider)
        .requireValue
        .friends
        .map((u) => u.profile.id)
        .toList();

    test('serves the new user data after a user switch', () async {
      start(
        userId: 'user-a',
        overrides: [
          friendshipStreamRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(friendshipsRealtimeProvider, (_, __) {});
      await pumpEventQueue();
      expect(friendIds(), ['friend-of-user-a']);

      session
        ..signOut()
        ..signIn('user-b');
      await pumpEventQueue();

      expect(friendIds(), ['friend-of-user-b']);
    });

    test('stops serving the previous user data while signed out', () async {
      start(
        userId: 'user-a',
        overrides: [
          friendshipStreamRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(friendshipsRealtimeProvider, (_, __) {});
      await pumpEventQueue();
      clearInteractions(repository);

      session.signOut();
      await pumpEventQueue();

      // Stale data of user A must not stay served as if it were current:
      // riverpod keeps the previous value through a rebuild, so the signed-out
      // state emits an empty value that replaces it.
      verifyNever(repository.watchCurrentUserAllFriendships);
      final state = container.read(friendshipsRealtimeProvider);
      expect(state.hasError, isFalse);
      expect(state.valueOrNull?.isEmpty, isTrue);
      expect(
        await container.read(friendshipsRealtimeProvider.future),
        isNotNull,
      );
    });
  });

  group('friendshipsRealtimeProvider profile loading', () {
    late MockFriendshipStreamRepository repository;

    setUp(() {
      repository = MockFriendshipStreamRepository();
      when(repository.watchCurrentUserAllFriendships).thenAnswer(
        (_) => Stream.value(
          const FriendshipIds(
            friendsIds: ISetConst({'ok-1', 'ok-2', 'broken'}),
            pendingIds: ISetConst({'pending-1'}),
            requestedIds: ISetConst({}),
          ),
        ),
      );
    });

    void startWith(Object brokenError) {
      start(
        userId: 'user-a',
        overrides: [
          friendshipStreamRepositoryProvider.overrideWithValue(repository),
        ],
      );
      when(() => userService.getAppUserById('broken')).thenAnswer(
        (_) => Future<AppUser>.error(brokenError),
      );
      container.listen(friendshipsRealtimeProvider, (_, __) {});
    }

    test('emits the error instead of an empty list on a server failure',
        () async {
      final error = AppException(statusCode: 500, message: 'offline');
      startWith(error);
      await pumpEventQueue();

      final state = container.read(friendshipsRealtimeProvider);
      expect(state.hasError, isTrue);
      expect(state.error, error);
    });

    FriendshipIds friends(Set<String> ids) => FriendshipIds(
          friendsIds: ids.toISet(),
          pendingIds: const ISetConst({}),
          requestedIds: const ISetConst({}),
        );

    late StreamController<FriendshipIds> ids;

    void startWithController() {
      ids = StreamController<FriendshipIds>();
      addTearDown(ids.close);
      when(repository.watchCurrentUserAllFriendships)
          .thenAnswer((_) => ids.stream);
      start(
        userId: 'user-a',
        overrides: [
          friendshipStreamRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(friendshipsRealtimeProvider, (_, __) {});
    }

    List<String> friendIds() => container
        .read(friendshipsRealtimeProvider)
        .requireValue
        .friends
        .map((u) => u.profile.id)
        .toList();

    test('recovers from a first load failure when the same ids reload',
        () async {
      startWithController();
      when(() => userService.getAppUserById('broken')).thenAnswer(
        (_) => Future<AppUser>.error(AppException(statusCode: 500)),
      );

      ids.add(friends({'broken'}));
      await pumpEventQueue();
      expect(container.read(friendshipsRealtimeProvider).hasError, isTrue);

      when(() => userService.getAppUserById('broken')).thenAnswer(
        (_) async => _appUserFor('broken'),
      );
      ids.add(friends({'broken'}));
      await pumpEventQueue();

      final state = container.read(friendshipsRealtimeProvider);
      expect(state.hasError, isFalse);
      expect(friendIds(), ['broken']);
    });

    test('keeps the last value when a later reload fails', () async {
      startWithController();
      when(() => userService.getAppUserById('broken')).thenAnswer(
        (_) async => _appUserFor('broken'),
      );

      ids.add(friends({'ok-1'}));
      await pumpEventQueue();
      expect(friendIds(), ['ok-1']);

      when(() => userService.getAppUserById('broken')).thenAnswer(
        (_) => Future<AppUser>.error(AppException(statusCode: 500)),
      );
      ids.add(friends({'ok-1', 'broken'}));
      await pumpEventQueue();

      final state = container.read(friendshipsRealtimeProvider);
      expect(state.hasError, isFalse);
      expect(friendIds(), ['ok-1']);

      // Not stuck: the next successful reload replaces the kept value.
      when(() => userService.getAppUserById('broken')).thenAnswer(
        (_) async => _appUserFor('broken'),
      );
      ids.add(friends({'ok-1', 'broken'}));
      await pumpEventQueue();
      expect(friendIds().toSet(), {'ok-1', 'broken'});
    });

    test('skips only a profile that does not exist', () async {
      startWith(
        AppException(
          statusCode: 500,
          cause: const PostgrestException(
            message: 'no rows',
            code: 'PGRST116',
          ),
        ),
      );
      await pumpEventQueue();

      final data = container.read(friendshipsRealtimeProvider).requireValue;
      expect(
        data.friends.map((u) => u.profile.id).toSet(),
        {'ok-1', 'ok-2'},
      );
      expect(data.pendingFriends.map((u) => u.profile.id), ['pending-1']);
    });
  });

  group('wishlistsRealtimeProvider', () {
    test('watches the wishlists of the new user after a user switch', () async {
      final repository = MockWishlistStreamRepository();
      when(() => repository.watchWishlistsByUser(any())).thenAnswer(
        (i) => Stream.value(
          IList([_wishlistOf(i.positionalArguments.first as String)]),
        ),
      );
      start(
        userId: 'user-a',
        overrides: [
          wishlistStreamRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(wishlistsRealtimeProvider, (_, __) {});
      await pumpEventQueue();

      session
        ..signOut()
        ..signIn('user-b');
      await pumpEventQueue();

      verify(() => repository.watchWishlistsByUser('user-a')).called(1);
      verify(() => repository.watchWishlistsByUser('user-b')).called(1);
      expect(
        container.read(wishlistsRealtimeProvider).requireValue.single.idOwner,
        'user-b',
      );
    });

    test('stops serving the previous user wishlists while signed out',
        () async {
      final repository = MockWishlistStreamRepository();
      when(() => repository.watchWishlistsByUser(any()))
          .thenAnswer((_) => Stream.value(IList([_wishlistOf('user-a')])));
      start(
        userId: 'user-a',
        overrides: [
          wishlistStreamRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(wishlistsRealtimeProvider, (_, __) {});
      await pumpEventQueue();

      session.signOut();
      await pumpEventQueue();

      final state = container.read(wishlistsRealtimeProvider);
      expect(state.hasError, isFalse);
      expect(state.valueOrNull, isEmpty);
      expect(await container.read(wishlistsRealtimeProvider.future), isEmpty);
      verify(() => repository.watchWishlistsByUser(any())).called(1);
    });
  });

  group('bookedWishesRealtimeProvider', () {
    test('watches the booked wishes of the new user', () async {
      final repository = MockWishStreamRepository();
      when(() => repository.watchBookedWishesByUser(any()))
          .thenAnswer((_) => Stream.value(const IListConst([])));
      start(
        userId: 'user-a',
        overrides: [wishStreamRepositoryProvider.overrideWithValue(repository)],
      );
      container.listen(bookedWishesRealtimeProvider, (_, __) {});
      await pumpEventQueue();

      session
        ..signOut()
        ..signIn('user-b');
      await pumpEventQueue();

      verify(() => repository.watchBookedWishesByUser('user-a')).called(1);
      verify(() => repository.watchBookedWishesByUser('user-b')).called(1);
    });

    test('stops serving the previous user booked wishes while signed out',
        () async {
      final repository = MockWishStreamRepository();
      when(() => repository.watchBookedWishesByUser(any()))
          .thenAnswer((_) => Stream.value(IList([fakeBookedWish1])));
      start(
        userId: 'user-a',
        overrides: [wishStreamRepositoryProvider.overrideWithValue(repository)],
      );
      container.listen(bookedWishesRealtimeProvider, (_, __) {});
      await pumpEventQueue();
      expect(
        container.read(bookedWishesRealtimeProvider).valueOrNull,
        hasLength(1),
      );

      session.signOut();
      await pumpEventQueue();

      final state = container.read(bookedWishesRealtimeProvider);
      expect(state.hasError, isFalse);
      expect(state.valueOrNull, isEmpty);
      expect(
        await container.read(bookedWishesRealtimeProvider.future),
        isEmpty,
      );
    });
  });

  group('completedWishesRealtimeProvider', () {
    test('stops serving the previous user completed wishes while signed out',
        () async {
      final repository = MockCompletedWishStreamRepository();
      when(() => repository.watchCompletedWishesByUser(any()))
          .thenAnswer((_) => Stream.value(IList([_completedWish])));
      start(
        userId: 'user-a',
        overrides: [
          userCompletedWishStreamRepositoryProvider
              .overrideWithValue(repository),
        ],
      );
      container.listen(completedWishesRealtimeProvider, (_, __) {});
      await pumpEventQueue();
      expect(
        container.read(completedWishesRealtimeProvider).valueOrNull,
        hasLength(1),
      );

      session.signOut();
      await pumpEventQueue();

      final state = container.read(completedWishesRealtimeProvider);
      expect(state.hasError, isFalse);
      expect(state.valueOrNull, isEmpty);
      expect(
        await container.read(completedWishesRealtimeProvider.future),
        isEmpty,
      );
    });
  });

  group('receivedWishesSummaryProvider', () {
    test('stops serving the previous user summary while signed out', () async {
      final repository = MockCompletedWishStreamRepository();
      when(() => repository.watchReceivedWishesSummary(any())).thenAnswer(
        (_) => Stream.value(const ReceivedWishesSummary(count: 3)),
      );
      start(
        userId: 'user-a',
        overrides: [
          userCompletedWishStreamRepositoryProvider
              .overrideWithValue(repository),
        ],
      );
      container.listen(receivedWishesSummaryProvider, (_, __) {});
      await pumpEventQueue();
      expect(
        container.read(receivedWishesSummaryProvider).valueOrNull?.count,
        3,
      );

      session.signOut();
      await pumpEventQueue();

      final state = container.read(receivedWishesSummaryProvider);
      expect(state.hasError, isFalse);
      expect(state.valueOrNull?.count, 0);
    });
  });

  group('friends ids providers', () {
    test('open the friends stream of the user they were built for', () async {
      final repository = MockFriendshipStreamRepository();
      when(() => repository.watchFriendsIds(any()))
          .thenAnswer((_) => Stream.value(const ISetConst({'f'})));
      start(
        userId: 'user-a',
        overrides: [
          friendshipStreamRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(watchCurrentUserFriendsIdsProvider, (_, __) {});
      await pumpEventQueue();

      session.setUserSilently(null);
      container.invalidate(watchCurrentUserFriendsIdsProvider);
      await pumpEventQueue();

      expect(
        container.read(watchCurrentUserFriendsIdsProvider).hasError,
        isFalse,
      );
      verify(() => repository.watchFriendsIds('user-a')).called(2);
    });

    test('stop serving the previous user ids while signed out', () async {
      final repository = MockFriendshipStreamRepository();
      when(() => repository.watchFriendsIds(any()))
          .thenAnswer((_) => Stream.value(const ISetConst({'f'})));
      when(repository.watchCurrentUserPendingFriendsIds)
          .thenAnswer((_) => Stream.value(const ISetConst({'p'})));
      when(repository.watchCurrentUserRequestedFriendsIds)
          .thenAnswer((_) => Stream.value(const ISetConst({'r'})));
      start(
        userId: 'user-a',
        overrides: [
          friendshipStreamRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final providers = [
        watchCurrentUserFriendsIdsProvider,
        watchCurrentUserPendingFriendsIdsProvider,
        watchCurrentUserRequestedFriendsIdsProvider,
      ];
      for (final p in providers) {
        container.listen(p, (_, __) {});
      }
      await pumpEventQueue();
      for (final p in providers) {
        expect(container.read(p).valueOrNull, hasLength(1));
      }

      session.signOut();
      await pumpEventQueue();

      for (final p in providers) {
        final state = container.read(p);
        expect(state.hasError, isFalse);
        expect(state.valueOrNull, isEmpty);
        expect(await container.read(p.future), isEmpty);
      }
    });
  });

  group('currentUserProfileProvider', () {
    test('loads the profile of the new user after a user switch', () async {
      start(userId: 'user-a');
      container.listen(currentUserProfileProvider, (_, __) {});
      await pumpEventQueue();
      expect(
        container.read(currentUserProfileProvider).requireValue.profile.id,
        'user-a',
      );

      session
        ..signOut()
        ..signIn('user-b');
      await pumpEventQueue();

      expect(
        container.read(currentUserProfileProvider).requireValue.profile.id,
        'user-b',
      );
    });
  });

  group('watchCurrentUserProfileProvider', () {
    test('watches the profile of the new user after a user switch', () async {
      final repository = MockUserStreamRepository();
      when(() => repository.watchProfileById(any())).thenAnswer(
        (i) => Stream.value(
          Profile(id: i.positionalArguments.first as String, pseudo: 'p'),
        ),
      );
      start(
        userId: 'user-a',
        overrides: [userStreamRepositoryProvider.overrideWithValue(repository)],
      );
      container.listen(watchCurrentUserProfileProvider, (_, __) {});
      await pumpEventQueue();

      session
        ..signOut()
        ..signIn('user-b');
      await pumpEventQueue();

      expect(
        container.read(watchCurrentUserProfileProvider).requireValue?.id,
        'user-b',
      );
    });

    test('opens the stream of the user it was built for', () async {
      final repository = MockUserStreamRepository();
      when(() => repository.watchProfileById(any())).thenAnswer(
        (i) => Stream.value(
          Profile(id: i.positionalArguments.first as String, pseudo: 'p'),
        ),
      );
      start(
        userId: 'user-a',
        overrides: [userStreamRepositoryProvider.overrideWithValue(repository)],
      );
      container.listen(watchCurrentUserProfileProvider, (_, __) {});
      await pumpEventQueue();

      // gotrue clears currentUser before it emits signedOut: a rebuild in that
      // window must not read the auth again.
      session.setUserSilently(null);
      container.invalidate(watchCurrentUserProfileProvider);
      await pumpEventQueue();

      final state = container.read(watchCurrentUserProfileProvider);
      expect(state.hasError, isFalse);
      expect(state.valueOrNull?.id, 'user-a');
    });

    test('stops serving the previous user profile while signed out', () async {
      final repository = MockUserStreamRepository();
      when(() => repository.watchProfileById(any())).thenAnswer(
        (i) => Stream.value(
          Profile(id: i.positionalArguments.first as String, pseudo: 'p'),
        ),
      );
      start(
        userId: 'user-a',
        overrides: [userStreamRepositoryProvider.overrideWithValue(repository)],
      );
      container.listen(watchCurrentUserProfileProvider, (_, __) {});
      await pumpEventQueue();
      expect(
        container.read(watchCurrentUserProfileProvider).valueOrNull?.id,
        'user-a',
      );

      session.signOut();
      await pumpEventQueue();

      final state = container.read(watchCurrentUserProfileProvider);
      expect(state.hasError, isFalse);
      expect(state.hasValue, isTrue);
      expect(state.valueOrNull, isNull);
      expect(
        await container.read(watchCurrentUserProfileProvider.future),
        isNull,
      );
    });
  });
}
