import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/infra/visible_birthdays_provider.dart';
import 'package:wishlist/shared/models/birthday.dart';

import '../../fixtures/fake_data.dart';
import '../../fixtures/fake_providers.dart';
import '../../fixtures/mock_supabase.dart';

const _march12 = Birthday(month: 3, day: 12);

void main() {
  late MockUserService userService;
  late StreamController<FriendsData> friendships;

  setUp(() {
    userService = MockUserService();
    friendships = StreamController<FriendsData>();
    addTearDown(friendships.close);
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
    when(userService.getVisibleBirthdays)
        .thenAnswer((_) async => {fakeFriendUserId1: _march12});
    final container = makeContainer();

    final birthdays = await container.read(visibleBirthdaysProvider.future);

    expect(birthdays, {fakeFriendUserId1: _march12});
    expect(container.read(friendBirthdayProvider(fakeFriendUserId1)), _march12);
    expect(container.read(friendBirthdayProvider(fakeFriendUserId2)), isNull);
  });

  test('a failed load gives no birthday instead of an error', () async {
    when(userService.getVisibleBirthdays)
        .thenThrow(AppException(statusCode: 500));
    final container = makeContainer();

    final birthdays = await container.read(visibleBirthdaysProvider.future);

    expect(birthdays, isEmpty);
    expect(container.read(friendBirthdayProvider(fakeFriendUserId1)), isNull);
  });

  test('does not read anything without a session', () async {
    when(userService.getVisibleBirthdays)
        .thenAnswer((_) async => {fakeFriendUserId1: _march12});
    final container = makeContainer(signedOut: true);

    final birthdays = await container.read(visibleBirthdaysProvider.future);

    expect(birthdays, isEmpty);
    verifyNever(userService.getVisibleBirthdays);
  });

  test('reloads when the set of friends changes, not on other changes',
      () async {
    var loads = 0;
    when(userService.getVisibleBirthdays).thenAnswer((_) async {
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
    final birthdays = await container.read(visibleBirthdaysProvider.future);
    expect(birthdays, {fakeFriendUserId1: _march12});
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

  test('lets an unexpected error through, the consumers read no value',
      () async {
    when(userService.getVisibleBirthdays).thenThrow(StateError('bug'));
    final container = makeContainer();

    await expectLater(
      container.read(visibleBirthdaysProvider.future),
      throwsStateError,
    );
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
      return container;
    }

    setUp(() {
      session = FakeAuthSession(userId: 'user-a');
      addTearDown(session.close);
    });

    test('hides the previous user birthdays while the new ones load', () async {
      var loads = 0;
      final secondLoad = Completer<Map<String, Birthday>>();
      when(userService.getVisibleBirthdays).thenAnswer((_) {
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

    test('keeps the values while a refresh reloads', () async {
      var loads = 0;
      final secondLoad = Completer<Map<String, Birthday>>();
      when(userService.getVisibleBirthdays).thenAnswer((_) {
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
