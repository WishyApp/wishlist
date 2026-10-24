import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/infra/visible_birthdays_provider.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';

import '../../fixtures/fake_data.dart';
import '../../fixtures/fake_providers.dart';
import '../../fixtures/mock_supabase.dart';

const _march12 = Birthday(month: 3, day: 12);

FriendsData _friendsData(List<AppUser> friends) => FriendsData(
      friends: friends.toIList(),
      pendingFriends: const IListConst([]),
      requestedFriends: const IListConst([]),
    );

void main() {
  late MockUserService userService;
  late StreamController<FriendsData> friendships;

  setUpAll(() => registerFallbackValue(const ISetConst<String>({})));

  setUp(() {
    userService = MockUserService();
    friendships = StreamController<FriendsData>();
    // Not awaited: close() never completes for a controller nobody listened to
    addTearDown(() => unawaited(friendships.close()));
  });

  ProviderContainer makeContainer({bool signedOut = false}) {
    final container = ProviderContainer(
      overrides: [
        supabaseClientOverride(signedOut: signedOut),
        userServiceProvider.overrideWithValue(userService),
        friendshipsRealtimeProvider.overrideWith((ref) => friendships.stream),
      ],
    );
    addTearDown(container.dispose);
    // Keeps the autoDispose providers alive, like a listening widget.
    container.listen(visibleBirthdaysProvider, (_, __) {});
    return container;
  }

  test('maps the visible birthdays by profile id', () async {
    when(() => userService.getVisibleBirthdays(any()))
        .thenAnswer((_) async => {fakeFriendUserId1: _march12});
    final container = makeContainer();
    friendships.add(_friendsData([fakeFriendAppUser1]));

    final data = await container.read(visibleBirthdaysProvider.future);

    expect(data.birthdays, {fakeFriendUserId1: _march12});
    expect(container.read(friendBirthdayProvider(fakeFriendUserId1)), _march12);
    verify(
      () => userService.getVisibleBirthdays({fakeFriendUserId1}.toISet()),
    ).called(1);
    expect(container.read(friendBirthdayProvider(fakeFriendUserId2)), isNull);
  });

  test('a failed load gives no birthday instead of an error', () async {
    when(() => userService.getVisibleBirthdays(any()))
        .thenThrow(AppException(statusCode: 500));
    final container = makeContainer();
    friendships.add(_friendsData([fakeFriendAppUser1]));

    final data = await container.read(visibleBirthdaysProvider.future);

    expect(data.birthdays, isEmpty);
    expect(container.read(friendBirthdayProvider(fakeFriendUserId1)), isNull);
  });

  test('does not read anything without a session', () async {
    when(() => userService.getVisibleBirthdays(any()))
        .thenAnswer((_) async => {fakeFriendUserId1: _march12});
    final container = makeContainer(signedOut: true);

    final data = await container.read(visibleBirthdaysProvider.future);

    expect(data.birthdays, isEmpty);
    verifyNever(() => userService.getVisibleBirthdays(any()));
  });

  test('reloads when the set of friends changes, not on other changes',
      () async {
    var loads = 0;
    when(() => userService.getVisibleBirthdays(any())).thenAnswer((_) async {
      loads++;
      return loads == 1 ? const {} : {fakeFriendUserId1: _march12};
    });
    final container = makeContainer();

    friendships.add(fakeEmptyFriendsData);
    await container.read(visibleBirthdaysProvider.future);
    expect(loads, 1);

    // A friendship gets accepted
    friendships.add(
      FriendsData(
        friends: [fakeFriendAppUser1].toIList(),
        pendingFriends: const IListConst([]),
        requestedFriends: const IListConst([]),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final data = await container.read(visibleBirthdaysProvider.future);
    expect(data.birthdays, {fakeFriendUserId1: _march12});
    expect(loads, 2);

    // Same friends, a pending request more: no reload
    friendships.add(
      FriendsData(
        friends: [fakeFriendAppUser1].toIList(),
        pendingFriends: [fakePendingAppUser].toIList(),
        requestedFriends: const IListConst([]),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await container.read(visibleBirthdaysProvider.future);
    expect(loads, 2);
  });

  test('waits for the list of friends before querying', () async {
    when(() => userService.getVisibleBirthdays(any()))
        .thenAnswer((_) async => {fakeFriendUserId1: _march12});
    final container = makeContainer();

    await pumpEventQueue();
    verifyNever(() => userService.getVisibleBirthdays(any()));
    expect(container.read(visibleBirthdaysProvider).isLoading, isTrue);

    friendships.add(_friendsData([fakeFriendAppUser1]));
    await container.read(visibleBirthdaysProvider.future);
    verify(() => userService.getVisibleBirthdays(any())).called(1);
  });

  test('any error gives no birthday, for the current user', () async {
    when(() => userService.getVisibleBirthdays(any()))
        .thenThrow(StateError('x'));
    final container = makeContainer();
    friendships.add(_friendsData([fakeFriendAppUser1]));

    final data = await container.read(visibleBirthdaysProvider.future);

    expect(data.birthdays, isEmpty);
    expect(container.read(friendBirthdayProvider(fakeFriendUserId1)), isNull);
  });

  group('user switch', () {
    late FakeAuthSession session;

    ProviderContainer makeSessionContainer() {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(session.client),
          userServiceProvider.overrideWithValue(userService),
          friendshipsRealtimeProvider.overrideWith((ref) => friendships.stream),
        ],
      );
      addTearDown(container.dispose);
      container.listen(visibleBirthdaysProvider, (_, __) {});
      container.listen(friendBirthdayProvider(fakeFriendUserId1), (_, __) {});
      friendships.add(_friendsData([fakeFriendAppUser1]));
      return container;
    }

    setUp(() {
      session = FakeAuthSession(userId: 'user-a');
      addTearDown(session.close);
    });

    test('hides the previous user birthdays while the new ones load', () async {
      var loads = 0;
      final secondLoad = Completer<Map<String, Birthday>>();
      when(() => userService.getVisibleBirthdays(any())).thenAnswer((_) {
        loads++;
        return loads == 1
            ? Future.value({fakeFriendUserId1: _march12})
            : secondLoad.future;
      });
      final container = makeSessionContainer();
      await container.read(visibleBirthdaysProvider.future);
      expect(
        container.read(friendBirthdayProvider(fakeFriendUserId1)),
        _march12,
      );

      session.signIn('user-b');
      await pumpEventQueue();

      expect(loads, 2);
      expect(container.read(friendBirthdayProvider(fakeFriendUserId1)), isNull);

      secondLoad
          .complete({fakeFriendUserId1: const Birthday(month: 5, day: 1)});
      await pumpEventQueue();
      expect(
        container.read(friendBirthdayProvider(fakeFriendUserId1)),
        const Birthday(month: 5, day: 1),
      );
    });

    test('keeps the badges while the friend list changes and reloads',
        () async {
      var loads = 0;
      final secondLoad = Completer<Map<String, Birthday>>();
      when(() => userService.getVisibleBirthdays(any())).thenAnswer((_) {
        loads++;
        return loads == 1
            ? Future.value({fakeFriendUserId1: _march12})
            : secondLoad.future;
      });
      final container = makeSessionContainer();
      await container.read(visibleBirthdaysProvider.future);

      friendships.add(_friendsData([fakeFriendAppUser1, fakeFriendAppUser2]));
      await pumpEventQueue();

      expect(loads, 2);
      expect(container.read(visibleBirthdaysProvider).isLoading, isTrue);
      expect(
        container.read(friendBirthdayProvider(fakeFriendUserId1)),
        _march12,
      );
    });

    test('does not show the previous user map after an error', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(session.client),
          visibleBirthdaysProvider.overrideWith((ref) async {
            final userId = ref.watch(currentUserIdProvider);
            if (userId == 'user-a') {
              return (
                userId: userId,
                birthdays: {fakeFriendUserId1: _march12},
              );
            }
            throw StateError('boom');
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(visibleBirthdaysProvider, (_, __) {});
      container.listen(friendBirthdayProvider(fakeFriendUserId1), (_, __) {});
      await container.read(visibleBirthdaysProvider.future);
      expect(
        container.read(friendBirthdayProvider(fakeFriendUserId1)),
        _march12,
      );

      session.signIn('user-b');
      await pumpEventQueue();

      // Riverpod keeps user A's value next to the error
      expect(container.read(visibleBirthdaysProvider).hasError, isTrue);
      expect(container.read(visibleBirthdaysProvider).valueOrNull, isNotNull);
      expect(container.read(friendBirthdayProvider(fakeFriendUserId1)), isNull);
    });

    test('keeps the values while a refresh reloads', () async {
      var loads = 0;
      final secondLoad = Completer<Map<String, Birthday>>();
      when(() => userService.getVisibleBirthdays(any())).thenAnswer((_) {
        loads++;
        return loads == 1
            ? Future.value({fakeFriendUserId1: _march12})
            : secondLoad.future;
      });
      final container = makeSessionContainer();
      await container.read(visibleBirthdaysProvider.future);

      container.invalidate(visibleBirthdaysProvider);
      await pumpEventQueue();

      expect(loads, 2);
      expect(
        container.read(friendBirthdayProvider(fakeFriendUserId1)),
        _march12,
      );
    });
  });
}
