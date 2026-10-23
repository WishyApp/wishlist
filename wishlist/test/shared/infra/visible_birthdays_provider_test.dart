import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
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
    when(userService.getVisibleBirthdays).thenThrow(Exception('boom'));
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
}
