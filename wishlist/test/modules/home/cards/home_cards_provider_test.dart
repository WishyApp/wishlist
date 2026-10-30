import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/modules/home/cards/wishlists_last_activity_provider.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/home_card/home_card_repository.dart';
import 'package:wishlist/shared/infra/repositories/home_card/home_card_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_repository.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository_provider.dart';
import 'package:wishlist/shared/infra/visible_birthdays_provider.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/card_state.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/fake_year_recap.dart';
import '../../../fixtures/mock_supabase.dart';

class MockHomeCardRepository extends Mock implements HomeCardRepository {}

class MockCardStateRepository extends Mock implements CardStateRepository {}

class MockBookedWishRemovalRepository extends Mock
    implements BookedWishRemovalRepository {}

class MockWishlistRepository extends Mock implements WishlistRepository {}

HomeCardDefinition def(
  String key,
  int priority, [
  Map<String, dynamic> params = const {},
]) {
  return HomeCardDefinition(
    key: key,
    kind: key == 'home_stack' ? HomeCardKind.settings : HomeCardKind.computed,
    priority: priority,
    params: params,
  );
}

// The seeds of the `home_cards` migration.
final seeds = [
  def('home_stack', 0, {'max_cards': 3, 'later_days': 1}),
  def('friend_birthday_today', 10),
  def('after_party', 15, {'days_after': 7}),
  def('onboarding', 18, {'optional_steps_hours': 48}),
  def('booked_reminder', 20, {'days_before': 14}),
  def('booked_wish_removed', 25),
  def('friend_birthday', 30, {
    'reminder_days': [30, 7],
    'highlight_days': 7,
  }),
  def('friend_accepted', 35, {'days': 7}),
  def('christmas', 40, {
    'reminder_days': [30, 7],
    'highlight_days': 7,
    'keywords': ['noel', 'christmas', 'xmas'],
  }),
  def('stale_wishlist', 60, {'stale_days': 90, 'snooze_days': 60}),
  def('year_recap', 28, {'month': 12}),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockHomeCardRepository homeCards;
  late MockCardStateRepository cardStates;
  late MockFriendshipRepository friendships;
  late MockBookedWishRemovalRepository removals;
  // Wednesday October 28th: no Christmas card, no booking within 14 days.
  final now = DateTime(2026, 10, 28, 10);

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    homeCards = MockHomeCardRepository();
    cardStates = MockCardStateRepository();
    friendships = MockFriendshipRepository();
    removals = MockBookedWishRemovalRepository();
    when(() => homeCards.getActiveCards()).thenAnswer((_) async => seeds);
    when(() => cardStates.getStates(any())).thenAnswer((_) async => const {});
    when(() => cardStates.recordShown(any())).thenAnswer((_) async {});
    when(
      () => friendships.getRecentlyAcceptedRequests(any()),
    ).thenAnswer((_) async => const []);
    when(() => removals.watchPending())
        .thenAnswer((_) => Stream.value(const []));
  });

  ProviderContainer containerFor({
    DateTime? at,
    Map<String, Birthday> birthdays = const {},
    Birthday? myBirthday = const Birthday(month: 1, day: 1),
    bool hasAvatar = true,
    List<Override> extra = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        ...homeScreenOverrides(
          birthdays: birthdays,
          now: at ?? now,
          overrideHomeCards: false,
          bookedWishes: fakeBookedWishes.clear(),
        ),
        currentUserBirthdayOverride(birthday: myBirthday),
        watchCurrentUserProfileOverride(
          profile: Profile(
            id: fakeCurrentUserId,
            pseudo: 'MonPseudo',
            avatarUrl: hasAvatar ? 'https://example.com/me.png' : null,
          ),
        ),
        homeCardRepositoryProvider.overrideWithValue(homeCards),
        cardStateRepositoryProvider.overrideWithValue(cardStates),
        friendshipRepositoryProvider.overrideWithValue(friendships),
        bookedWishRemovalRepositoryProvider.overrideWithValue(removals),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<List<HomeCardCandidate>> load({
    DateTime? at,
    Map<String, Birthday> birthdays = const {},
    Birthday? myBirthday = const Birthday(month: 1, day: 1),
    bool hasAvatar = true,
    List<Override> extra = const [],
  }) {
    return containerFor(
      at: at,
      birthdays: birthdays,
      myBirthday: myBirthday,
      hasAvatar: hasAvatar,
      extra: extra,
    ).read(homeCardsProvider.future);
  }

  Birthday tomorrow({DateTime? from}) {
    final date = (from ?? now).add(const Duration(days: 1));
    return Birthday(month: date.month, day: date.day);
  }

  test('a friend born tomorrow gives a highlighted friend_birthday card',
      () async {
    final cards = await load(
      birthdays: {fakeFriendUserId1: tomorrow()},
    );

    expect(cards, hasLength(1));
    expect(cards.single.type, 'friend_birthday');
    expect(cards.single.tone, HomeCardTone.highlighted);
    expect(
      cards.single.stateKey,
      'friend_birthday:$fakeFriendUserId1@2026',
    );
  });

  test('asks the states of the candidate keys and of the onboarding keys',
      () async {
    await load(birthdays: {fakeFriendUserId1: tomorrow()});

    final keys = verify(() => cardStates.getStates(captureAny()))
        .captured
        .single as Iterable<String>;
    expect(keys, [
      'friend_birthday:$fakeFriendUserId1@2026',
      'onboarding:optional_window',
      'onboarding:birthday',
      'onboarding:photo',
    ]);
  });

  test('home_cards unavailable gives an empty stack, not an error', () async {
    when(() => homeCards.getActiveCards()).thenThrow(Exception('offline'));

    expect(await load(birthdays: {fakeFriendUserId1: tomorrow()}), isEmpty);
  });

  test('card states unavailable gives an empty stack', () async {
    when(() => cardStates.getStates(any())).thenThrow(Exception('offline'));

    expect(await load(birthdays: {fakeFriendUserId1: tomorrow()}), isEmpty);
  });

  test('wishlists unavailable gives an empty stack, not a start card',
      () async {
    final cards = await load(
      extra: [
        wishlistsRealtimeProvider.overrideWith(
          (ref) => Stream.error(Exception('offline')),
        ),
      ],
    );

    expect(cards, isEmpty);
  });

  test('birthdays unavailable keeps the other cards', () async {
    final cards = await load(
      at: DateTime(2026, 12, 20, 9),
      extra: [
        visibleBirthdaysProvider.overrideWith(
          (ref) => throw Exception('offline'),
        ),
      ],
    );

    expect(cards.map((c) => c.type), ['christmas']);
  });

  test('my birthday unavailable offers no birthday step', () async {
    final cards = await load(
      extra: [
        currentUserBirthdayProvider.overrideWith(
          (ref) => throw Exception('offline'),
        ),
      ],
    );

    expect(cards, isEmpty);
  });

  test('max_cards limits the stack', () async {
    when(() => homeCards.getActiveCards()).thenAnswer(
      (_) async => [
        for (final seed in seeds)
          if (seed.key == 'home_stack')
            def('home_stack', 0, {'max_cards': 1})
          else
            seed,
      ],
    );
    final at = DateTime(2026, 12, 20, 9);

    final cards = await load(
      at: at,
      birthdays: {fakeFriendUserId1: tomorrow(from: at)},
    );

    // Both the friend birthday and Christmas qualify: the most urgent stays.
    expect(cards.map((c) => c.type), ['friend_birthday']);
  });

  test('a recently accepted request gives a friend_accepted card', () async {
    when(() => friendships.getRecentlyAcceptedRequests(any())).thenAnswer(
      (_) async => [
        (
          friendId: fakeFriendUserId1,
          acceptedAt: now.subtract(const Duration(days: 2)),
        ),
        // No longer a friend: no card.
        (friendId: 'gone', acceptedAt: now.subtract(const Duration(days: 1))),
      ],
    );

    final cards = await load();

    expect(
      cards.map((c) => c.stateKey),
      ['friend_accepted:$fakeFriendUserId1@${now.year}'],
    );
    final since = verify(
      () => friendships.getRecentlyAcceptedRequests(captureAny()),
    ).captured.single as DateTime;
    expect(since, now.subtract(const Duration(days: 7)));
  });

  test('accepted requests unavailable keep the other cards', () async {
    when(() => friendships.getRecentlyAcceptedRequests(any()))
        .thenThrow(Exception('offline'));

    final cards = await load(birthdays: {fakeFriendUserId1: tomorrow()});

    expect(cards.map((c) => c.type), ['friend_birthday']);
  });

  test('a pending removal alert gives a card', () async {
    when(() => removals.watchPending()).thenAnswer(
      (_) => Stream.value([
        BookedWishRemoval(
          id: 1,
          ownerId: fakeFriendUserId1,
          ownerPseudo: 'Alice',
          wishId: 9,
          wishName: 'Casque',
          quantity: 1,
          wishlistName: 'Noël',
          removedAt: now,
        ),
      ]),
    );

    final cards = await load();

    expect(cards.map((c) => c.type), ['booked_wish_removed']);
  });

  group('removal alert button', () {
    late MockWishlistRepository wishlistRepository;

    setUp(() {
      wishlistRepository = MockWishlistRepository();
      when(() => removals.watchPending()).thenAnswer(
        (_) => Stream.value([
          BookedWishRemoval(
            id: 1,
            ownerId: fakeFriendUserId1,
            ownerPseudo: 'Alice',
            wishId: 9,
            wishName: 'Casque',
            quantity: 1,
            wishlistName: 'Noël',
            removedAt: now,
          ),
        ]),
      );
    });

    Future<bool> canOpenList() async {
      final cards = await load(
        extra: [
          wishlistRepositoryProvider.overrideWithValue(wishlistRepository),
        ],
      );
      return (cards.single.content as BookedWishRemoved).canOpenList;
    }

    test('is offered to a friend whose wishlist is open', () async {
      when(() => wishlistRepository.getPublicWishlistsByUser(any())).thenAnswer(
        (_) async => [
          fakeWishlist1.copyWith(
            name: 'Noël',
            endDate: DateTime(2026, 12, 31),
          ),
        ].lock,
      );

      expect(await canOpenList(), isTrue);
    });

    test('is not offered when the wishlist is closed', () async {
      when(() => wishlistRepository.getPublicWishlistsByUser(any())).thenAnswer(
        (_) async => [
          fakeWishlist1.copyWith(
            name: 'Noël',
            endDate: DateTime(2026, 12, 31),
            isClosed: true,
          ),
        ].lock,
      );

      expect(await canOpenList(), isFalse);
    });

    test('is not offered when the wishlists cannot be loaded', () async {
      when(() => wishlistRepository.getPublicWishlistsByUser(any()))
          .thenThrow(Exception('boom'));

      expect(await canOpenList(), isFalse);
    });

    test('is only lost by the owner whose wishlists cannot be loaded',
        () async {
      BookedWishRemoval removalOf(int id, String ownerId) => BookedWishRemoval(
            id: id,
            ownerId: ownerId,
            ownerPseudo: 'Ami $id',
            wishId: id,
            wishName: 'Casque',
            quantity: 1,
            wishlistName: 'Noël',
            removedAt: now,
          );
      when(() => removals.watchPending()).thenAnswer(
        (_) => Stream.value([
          removalOf(1, fakeFriendUserId1),
          removalOf(2, fakeFriendUserId2),
        ]),
      );
      when(
        () => wishlistRepository.getPublicWishlistsByUser(fakeFriendUserId1),
      ).thenThrow(Exception('boom'));
      when(
        () => wishlistRepository.getPublicWishlistsByUser(fakeFriendUserId2),
      ).thenAnswer(
        (_) async => [
          fakeWishlist1.copyWith(
            name: 'Noël',
            endDate: DateTime(2026, 12, 31),
          ),
        ].lock,
      );

      final cards = await load(
        extra: [
          wishlistRepositoryProvider.overrideWithValue(wishlistRepository),
        ],
      );

      final canOpen = {
        for (final card in cards)
          (card.content as BookedWishRemoved).removal.ownerId:
              (card.content as BookedWishRemoved).canOpenList,
      };
      expect(canOpen, {fakeFriendUserId1: false, fakeFriendUserId2: true});
    });
  });

  group('onboarding window', () {
    test('is recorded once when an optional step is first offered', () async {
      final cards = await load(myBirthday: null);

      expect(cards.single.stateKey, 'onboarding:birthday');
      verify(() => cardStates.recordShown('onboarding:optional_window'))
          .called(1);
    });

    test('is not recorded again once it has a state', () async {
      when(() => cardStates.getStates(any())).thenAnswer(
        (_) async => {
          'onboarding:optional_window': CardState(
            cardKey: 'onboarding:optional_window',
            shownCount: 1,
            lastShownAt: now.subtract(const Duration(hours: 1)),
          ),
        },
      );

      final cards = await load(myBirthday: null);

      expect(cards.single.stateKey, 'onboarding:birthday');
      verifyNever(() => cardStates.recordShown(any()));
    });

    test('is not recorded for the first two steps', () async {
      final cards = await load(
        extra: [emptyWishlistsRealtimeOverride()],
      );

      expect(cards.single.stateKey, 'onboarding:firstWishlist');
      verifyNever(() => cardStates.recordShown(any()));
    });

    test('a failing record does not break the stack', () async {
      when(() => cardStates.recordShown(any())).thenThrow(Exception('offline'));

      final cards = await load(myBirthday: null);

      expect(cards.single.stateKey, 'onboarding:birthday');
    });
  });

  group('a failing source keeps the other cards', () {
    test('booked wish removals', () async {
      final cards = await load(
        birthdays: {fakeFriendUserId1: tomorrow()},
        extra: [
          pendingBookedWishRemovalsProvider.overrideWith(
            (ref) => Stream.error(Exception('offline')),
          ),
        ],
      );

      expect(cards.map((c) => c.type), ['friend_birthday']);
    });

    test('booked wishes', () async {
      final cards = await load(
        birthdays: {fakeFriendUserId1: tomorrow()},
        extra: [
          bookedWishesRealtimeProvider.overrideWith(
            (ref) => Stream.error(Exception('offline')),
          ),
        ],
      );

      expect(cards.map((c) => c.type), ['friend_birthday']);
    });

    test('the profile, taken as having a photo', () async {
      final cards = await load(
        birthdays: {fakeFriendUserId1: tomorrow()},
        hasAvatar: false,
        extra: [
          watchCurrentUserProfileProvider.overrideWith(
            (ref) => Stream.error(Exception('offline')),
          ),
        ],
      );

      expect(cards.map((c) => c.type), ['friend_birthday']);
    });
  });

  test('without friends, accepted requests are not even asked', () async {
    await load(
      extra: [
        friendshipsRealtimeOverride(friendsData: fakeEmptyFriendsData),
      ],
    );

    verifyNever(() => friendships.getRecentlyAcceptedRequests(any()));
  });

  test('the window is not recorded when the optional step is not on top',
      () async {
    final cards = await load(
      myBirthday: null,
      birthdays: {
        fakeFriendUserId1: Birthday(month: now.month, day: now.day),
      },
    );

    expect(cards.first.type, 'friend_birthday_today');
    expect(cards.map((c) => c.stateKey), contains('onboarding:birthday'));
    verifyNever(() => cardStates.recordShown(any()));
  });

  group('reloads', () {
    late BehaviorSubject<FriendsData> friendsStream;
    late BehaviorSubject<List<Wishlist>> wishlistsStream;
    late ProviderContainer container;

    FriendsData friendsWith(String avatar, {bool second = true}) {
      final first = AppUser(
        profile: Profile(
          id: fakeFriendUserId1,
          pseudo: 'Alice',
          avatarUrl: avatar,
        ),
        user: fakeFriendAppUser1.user,
      );
      return FriendsData(
        friends: [first, if (second) fakeFriendAppUser2].toIList(),
        pendingFriends: const IListConst([]),
        requestedFriends: const IListConst([]),
      );
    }

    setUp(() async {
      // Replays its last value: the provider may resubscribe.
      friendsStream = BehaviorSubject<FriendsData>();
      addTearDown(friendsStream.close);
      wishlistsStream = BehaviorSubject.seeded([fakeWishlist1]);
      addTearDown(wishlistsStream.close);
      container = ProviderContainer(
        overrides: [
          ...homeScreenOverrides(
            now: now,
            overrideHomeCards: false,
            bookedWishes: fakeBookedWishes.clear(),
          ),
          friendshipsRealtimeProvider
              .overrideWith((ref) => friendsStream.stream),
          wishlistsRealtimeProvider
              .overrideWith((ref) => wishlistsStream.stream),
          currentUserBirthdayOverride(
            birthday: const Birthday(month: 1, day: 1),
          ),
          watchCurrentUserProfileOverride(
            profile: Profile(
              id: fakeCurrentUserId,
              pseudo: 'MonPseudo',
              avatarUrl: 'https://example.com/me.png',
            ),
          ),
          homeCardRepositoryProvider.overrideWithValue(homeCards),
          cardStateRepositoryProvider.overrideWithValue(cardStates),
          friendshipRepositoryProvider.overrideWithValue(friendships),
          bookedWishRemovalRepositoryProvider.overrideWithValue(removals),
        ],
      );
      addTearDown(container.dispose);
      container.listen(homeCardsProvider, (_, __) {});
      friendsStream.add(friendsWith('a.png'));
      await container.read(homeCardsProvider.future);
    });

    test('a change outside the watched slices loads nothing again', () async {
      friendsStream.add(friendsWith('b.png'));
      await pumpEventQueue();
      await container.read(homeCardsProvider.future);

      verify(() => homeCards.getActiveCards()).called(1);
      verify(() => cardStates.getStates(any())).called(1);
    });

    test('closing a wishlist reloads the cards', () async {
      wishlistsStream.add([fakeWishlist1.copyWith(isClosed: true)]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await container.read(homeCardsProvider.future);

      verify(() => cardStates.getStates(any())).called(2);
    });

    test('a new friend reloads the cards but not the definitions', () async {
      friendsStream.add(friendsWith('a.png', second: false));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await container.read(homeCardsProvider.future);

      verify(() => homeCards.getActiveCards()).called(1);
      verify(() => cardStates.getStates(any())).called(2);
    });
  });

  group('onboarding step 2', () {
    FriendsData onlyPending() => FriendsData(
          friends: const IListConst([]),
          pendingFriends: [fakePendingAppUser].toIList(),
          requestedFriends: const IListConst([]),
        );

    test('a sent request is enough: step 3 comes next', () async {
      final cards = await load(
        myBirthday: null,
        extra: [friendshipsRealtimeOverride(friendsData: onlyPending())],
      );

      expect(cards.single.stateKey, 'onboarding:birthday');
    });

    test('a received request is not: step 2 stays', () async {
      final cards = await load(
        extra: [
          friendshipsRealtimeOverride(
            friendsData: FriendsData(
              friends: const IListConst([]),
              pendingFriends: const IListConst([]),
              requestedFriends: [fakeRequestedAppUser].toIList(),
            ),
          ),
        ],
      );

      expect(cards.single.stateKey, 'onboarding:firstFriend');
    });
  });

  group('stale wishlist', () {
    late MockWishlistRepository wishlistRepository;

    setUp(() {
      wishlistRepository = MockWishlistRepository();
    });

    Future<List<HomeCardCandidate>> loadWithActivity() => load(
          extra: [
            wishlistRepositoryProvider.overrideWithValue(wishlistRepository),
          ],
        );

    test('the list idle the longest gives a card', () async {
      when(() => wishlistRepository.getLastActivityByWishlist()).thenAnswer(
        (_) async => {
          fakeWishlist1.id: DateTime(2026, 7, 2),
          fakeWishlist2.id: DateTime(2026, 5, 2),
          fakeWishlist3.id: DateTime(2026, 10, 2),
        },
      );

      final cards = await loadWithActivity();

      expect(cards.single.type, 'stale_wishlist');
      expect(cards.single.stateKey, 'stale_wishlist:${fakeWishlist2.id}');
    });

    test('the last activity is fetched while the other sources load', () async {
      // The accepted requests only answer once the activity was asked for:
      // loaded one after the other, the stack would never come.
      final activityAsked = Completer<void>();
      when(() => friendships.getRecentlyAcceptedRequests(any())).thenAnswer(
        (_) async {
          await activityAsked.future;
          return const [];
        },
      );
      when(() => wishlistRepository.getLastActivityByWishlist()).thenAnswer(
        (_) async {
          activityAsked.complete();
          return {fakeWishlist1.id: DateTime(2026, 5, 2)};
        },
      );

      final cards = await loadWithActivity().timeout(
        const Duration(seconds: 2),
      );

      expect(cards.single.stateKey, 'stale_wishlist:${fakeWishlist1.id}');
    });

    test('a snoozed list makes room for the next oldest one', () async {
      when(() => wishlistRepository.getLastActivityByWishlist()).thenAnswer(
        (_) async => {
          fakeWishlist1.id: DateTime(2026, 7, 2),
          fakeWishlist2.id: DateTime(2026, 5, 2),
          fakeWishlist3.id: DateTime(2026, 6, 2),
        },
      );
      final key = 'stale_wishlist:${fakeWishlist2.id}';
      when(() => cardStates.getStates(any())).thenAnswer(
        (_) async => {
          key: CardState(
            cardKey: key,
            shownCount: 1,
            dismissedAt: now,
            snoozedUntil: now.add(const Duration(days: 30)),
          ),
        },
      );

      final cards = await loadWithActivity();

      expect(cards.single.stateKey, 'stale_wishlist:${fakeWishlist3.id}');
    });

    test('the last activity unavailable only loses this card', () async {
      when(() => wishlistRepository.getLastActivityByWishlist())
          .thenThrow(Exception('offline'));

      final cards = await load(
        birthdays: {fakeFriendUserId1: tomorrow()},
        extra: [
          wishlistRepositoryProvider.overrideWithValue(wishlistRepository),
        ],
      );

      expect(cards.single.type, 'friend_birthday');
    });

    group('its own provider', () {
      setUp(() {
        when(() => wishlistRepository.getLastActivityByWishlist()).thenAnswer(
          (_) async => {fakeWishlist1.id: DateTime(2026, 5, 2)},
        );
      });

      ProviderContainer homeContainer() => containerFor(
            extra: [
              wishlistRepositoryProvider.overrideWithValue(wishlistRepository),
            ],
          );

      test('a reload of the cards does not ask it again', () async {
        final container = homeContainer();
        final subscription = container.listen(
          homeCardsProvider,
          (_, __) {},
        );
        addTearDown(subscription.close);
        await container.read(homeCardsProvider.future);

        // What a swipe or a change of bookings does
        container.invalidate(homeCardsProvider);
        final cards = await container.read(homeCardsProvider.future);

        expect(cards.single.stateKey, 'stale_wishlist:${fakeWishlist1.id}');
        verify(() => wishlistRepository.getLastActivityByWishlist()).called(1);
      });

      test('invalidating it reloads the cards from a fresh read', () async {
        final container = homeContainer();
        final subscription = container.listen(
          homeCardsProvider,
          (_, __) {},
        );
        addTearDown(subscription.close);
        expect(
          (await container.read(homeCardsProvider.future)).single.stateKey,
          'stale_wishlist:${fakeWishlist1.id}',
        );
        // The user touched the list since: it is not stale anymore
        when(() => wishlistRepository.getLastActivityByWishlist()).thenAnswer(
          (_) async => {fakeWishlist1.id: now},
        );

        container.invalidate(wishlistsLastActivityProvider);
        final cards = await container.read(homeCardsProvider.future);

        expect(cards.where((card) => card.type == 'stale_wishlist'), isEmpty);
        verify(() => wishlistRepository.getLastActivityByWishlist()).called(2);
      });
    });

    test('is not asked when the card type is disabled', () async {
      when(() => homeCards.getActiveCards()).thenAnswer(
        (_) async => [
          for (final seed in seeds)
            if (seed.key != 'stale_wishlist') seed,
        ],
      );

      await loadWithActivity();

      verifyNever(() => wishlistRepository.getLastActivityByWishlist());
    });
  });

  group('year recap', () {
    late MockYearRecapRepository recapRepository;
    var realtimeListened = false;

    setUp(() {
      recapRepository = MockYearRecapRepository();
      realtimeListened = false;
      when(() => recapRepository.getMyYearRecap(any())).thenAnswer(
        (_) async => fakeYearRecap(
          stats: YearRecapStats(
            received: 2,
            longestAwaited: fakeLongestAwaited(createdOn: DateTime(2024, 6, 2)),
          ),
        ),
      );
    });

    Future<List<HomeCardCandidate>> loadAll(DateTime at) => load(
          at: at,
          extra: [
            yearRecapRepositoryProvider.overrideWithValue(recapRepository),
            // The live stream is the heavy one: the home must never listen
            completedWishesRealtimeProvider.overrideWith((ref) {
              realtimeListened = true;
              return Stream.value(const IListConst([]));
            }),
          ],
        );

    // Christmas cards share the stack in December: look at the recap only
    Future<List<HomeCardCandidate>> loadRecap(DateTime at) async => [
          for (final card in await loadAll(at))
            if (card.type == 'year_recap') card,
        ];

    test('the recap is read while the other sources load', () async {
      // The accepted requests only answer once the received wishes were
      // asked for: loaded one after the other, the stack would never come.
      final recapAsked = Completer<void>();
      when(() => friendships.getRecentlyAcceptedRequests(any())).thenAnswer(
        (_) async {
          await recapAsked.future;
          return const [];
        },
      );
      when(() => recapRepository.getMyYearRecap(any())).thenAnswer((_) async {
        if (!recapAsked.isCompleted) {
          recapAsked.complete();
        }
        return fakeYearRecap(stats: const YearRecapStats(received: 2));
      });

      final cards = await loadRecap(DateTime(2026, 12, 10, 9)).timeout(
        const Duration(seconds: 2),
      );

      expect(cards, hasLength(1));
    });

    test('in December, a dark card with what was received and given', () async {
      final cards = await loadRecap(DateTime(2026, 12, 10, 9));

      expect(cards.single.type, 'year_recap');
      expect(cards.single.tone, HomeCardTone.dark);
      expect(cards.single.stateKey, 'year_recap@2026');
      final recap = (cards.single.content as YearRecap).recap;
      expect(recap.stats.received, 2);
      expect(recap.stats.offered, 0);
      expect(recap.stats.longestAwaited?.createdOn, DateTime(2024, 6, 2));
      // The summary of the received wishes may load after: one call or more
      verify(() => recapRepository.getMyYearRecap(2026));
    });

    test('outside December nothing is fetched nor listened to', () async {
      final cards = await loadRecap(DateTime(2026, 11, 30, 23));

      expect(cards, isEmpty);
      verifyNever(() => recapRepository.getMyYearRecap(any()));
      expect(realtimeListened, isFalse);
    });

    test('in December the live stream is still not listened to', () async {
      await loadRecap(DateTime(2026, 12, 10, 9));

      expect(realtimeListened, isFalse);
    });

    test('nothing without any activity in the year', () async {
      when(() => recapRepository.getMyYearRecap(any()))
          .thenAnswer((_) async => fakeYearRecap());

      expect(await loadRecap(DateTime(2026, 12, 10, 9)), isEmpty);
    });

    test('the recap unavailable only loses this card', () async {
      when(() => recapRepository.getMyYearRecap(any()))
          .thenThrow(Exception('offline'));

      final cards = await load(
        at: DateTime(2026, 12, 20, 9),
        birthdays: {fakeFriendUserId1: const Birthday(month: 12, day: 21)},
        extra: [
          yearRecapRepositoryProvider.overrideWithValue(recapRepository),
        ],
      );

      expect(cards.map((c) => c.type), contains('friend_birthday'));
    });
  });

  group('the day changes', () {
    // Recomputes are counted by the states they ask.
    var stateCalls = 0;
    int computations() => stateCalls;

    setUp(() {
      stateCalls = 0;
      when(() => cardStates.getStates(any())).thenAnswer((_) async {
        stateCalls++;
        return const {};
      });
    });

    late ProviderSubscription<AsyncValue<List<HomeCardCandidate>>> listener;

    ProviderContainer containerWithClock(DateTime Function() clock) {
      final container = ProviderContainer(
        overrides: [
          ...homeScreenOverrides(
            bookedWishes: fakeBookedWishes.clear(),
            overrideHomeCards: false,
          ),
          clockProvider.overrideWithValue(clock),
          currentUserBirthdayOverride(
            birthday: const Birthday(month: 1, day: 1),
          ),
          watchCurrentUserProfileOverride(
            profile: Profile(
              id: fakeCurrentUserId,
              pseudo: 'MonPseudo',
              avatarUrl: 'https://example.com/me.png',
            ),
          ),
          homeCardRepositoryProvider.overrideWithValue(homeCards),
          cardStateRepositoryProvider.overrideWithValue(cardStates),
          friendshipRepositoryProvider.overrideWithValue(friendships),
          bookedWishRemovalRepositoryProvider.overrideWithValue(removals),
        ],
      );
      addTearDown(container.dispose);
      listener = container.listen(homeCardsProvider, (_, __) {});
      return container;
    }

    test('the cards are recomputed at the next local midnight', () {
      fakeAsync((async) {
        final start = DateTime(2026, 10, 28, 23);
        final container = containerWithClock(() => start.add(async.elapsed));
        async.flushMicrotasks();
        expect(computations(), 1);

        async.elapse(const Duration(minutes: 59));
        async.flushMicrotasks();
        expect(computations(), 1);

        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();
        expect(computations(), 2);

        // Then at the next one.
        async.elapse(const Duration(days: 1));
        async.flushMicrotasks();
        expect(computations(), 3);
        container.dispose();
      });
    });

    test('a disposed provider no longer recomputes', () {
      fakeAsync((async) {
        final start = DateTime(2026, 10, 28, 23);
        containerWithClock(() => start.add(async.elapsed));
        async.flushMicrotasks();
        // Only the provider goes away (nobody listens), the container lives.
        listener.close();
        async.elapse(Duration.zero);
        // Invalidating a disposed provider is silent: the midnight timer
        // itself must be gone.
        expect(async.nonPeriodicTimerCount, 0);

        async.elapse(const Duration(days: 3));
        async.flushMicrotasks();
        expect(computations(), 1);
      });
    });

    void background(TestWidgetsFlutterBinding binding) {
      [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ].forEach(binding.handleAppLifecycleStateChanged);
    }

    void foreground(TestWidgetsFlutterBinding binding) {
      [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ].forEach(binding.handleAppLifecycleStateChanged);
    }

    test('coming back to the foreground on another day recomputes', () {
      fakeAsync((async) {
        var current = DateTime(2026, 10, 28, 10);
        containerWithClock(() => current);
        async.flushMicrotasks();
        final binding = TestWidgetsFlutterBinding.instance;

        // The same day: nothing to do.
        background(binding);
        foreground(binding);
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(computations(), 1);

        background(binding);
        current = DateTime(2026, 10, 29, 8);
        foreground(binding);
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(computations(), 2);
      });
    });
  });

  group('the reminder of a booked wish', () {
    // Wednesday December 16th: Christmas is within the 14 days.
    final christmasWeek = DateTime(2026, 12, 16, 10);

    BookedWishWithDetails booking(String wishlistName) => BookedWishWithDetails(
          wish: fakeWish1,
          bookedQuantity: 1,
          wishlistName: wishlistName,
          ownerPseudo: 'Alice',
          ownerId: fakeFriendUserId1,
        );

    ProviderContainer containerWith(
      Stream<IList<BookedWishWithDetails>> stream,
    ) {
      final container = ProviderContainer(
        overrides: [
          ...homeScreenOverrides(now: christmasWeek, overrideHomeCards: false),
          bookedWishesRealtimeProvider.overrideWith((ref) => stream),
          currentUserBirthdayOverride(
            birthday: const Birthday(month: 1, day: 1),
          ),
          watchCurrentUserProfileOverride(
            profile: Profile(
              id: fakeCurrentUserId,
              pseudo: 'MonPseudo',
              avatarUrl: 'https://example.com/me.png',
            ),
          ),
          homeCardRepositoryProvider.overrideWithValue(homeCards),
          cardStateRepositoryProvider.overrideWithValue(cardStates),
          friendshipRepositoryProvider.overrideWithValue(friendships),
          bookedWishRemovalRepositoryProvider.overrideWithValue(removals),
        ],
      );
      addTearDown(container.dispose);
      container.listen(homeCardsProvider, (_, __) {});
      return container;
    }

    test('renaming the list of a booked wish recomputes the cards', () async {
      final stream = BehaviorSubject<IList<BookedWishWithDetails>>.seeded(
        [booking('Anniversaire')].toIList(),
      );
      addTearDown(stream.close);
      final container = containerWith(stream.stream);
      final before = await container.read(homeCardsProvider.future);
      expect(before.map((c) => c.type), isNot(contains('booked_reminder')));

      stream.add([booking('Noël 2026')].toIList());
      await pumpEventQueue();
      final after = await container.read(homeCardsProvider.future);

      expect(after.map((c) => c.type), contains('booked_reminder'));
    });

    test('the keywords of the christmas definition decide the occasion',
        () async {
      when(() => homeCards.getActiveCards()).thenAnswer(
        (_) async => [
          for (final seed in seeds)
            if (seed.key == 'christmas')
              def('christmas', 40, {
                'reminder_days': [30, 7],
                'highlight_days': 7,
                'keywords': ['sapin'],
              })
            else
              seed,
        ],
      );
      final container = containerWith(
        Stream.value([booking('Sapin 2026')].toIList()),
      );

      final cards = await container.read(homeCardsProvider.future);

      expect(cards.map((c) => c.type), contains('booked_reminder'));
    });
  });

  test('a failed record of the onboarding window is tried again', () async {
    var attempts = 0;
    when(() => cardStates.recordShown(any())).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        throw Exception('offline');
      }
    });
    final container = ProviderContainer(
      overrides: [
        ...homeScreenOverrides(
          now: now,
          bookedWishes: fakeBookedWishes.clear(),
          overrideHomeCards: false,
        ),
        currentUserBirthdayOverride(),
        watchCurrentUserProfileOverride(
          profile: Profile(
            id: fakeCurrentUserId,
            pseudo: 'MonPseudo',
            avatarUrl: 'https://example.com/me.png',
          ),
        ),
        homeCardRepositoryProvider.overrideWithValue(homeCards),
        cardStateRepositoryProvider.overrideWithValue(cardStates),
        friendshipRepositoryProvider.overrideWithValue(friendships),
        bookedWishRemovalRepositoryProvider.overrideWithValue(removals),
      ],
    );
    addTearDown(container.dispose);
    container.listen(homeCardsProvider, (_, __) {});
    await container.read(homeCardsProvider.future);
    await pumpEventQueue();

    container.invalidate(homeCardsProvider);
    await container.read(homeCardsProvider.future);
    await pumpEventQueue();

    expect(attempts, 2);
  });

  test('the onboarding window is recorded once across recomputes', () async {
    final container = ProviderContainer(
      overrides: [
        ...homeScreenOverrides(
          now: now,
          bookedWishes: fakeBookedWishes.clear(),
          overrideHomeCards: false,
        ),
        currentUserBirthdayOverride(),
        watchCurrentUserProfileOverride(
          profile: Profile(
            id: fakeCurrentUserId,
            pseudo: 'MonPseudo',
            avatarUrl: 'https://example.com/me.png',
          ),
        ),
        homeCardRepositoryProvider.overrideWithValue(homeCards),
        cardStateRepositoryProvider.overrideWithValue(cardStates),
        friendshipRepositoryProvider.overrideWithValue(friendships),
        bookedWishRemovalRepositoryProvider.overrideWithValue(removals),
      ],
    );
    addTearDown(container.dispose);
    container.listen(homeCardsProvider, (_, __) {});
    await container.read(homeCardsProvider.future);

    // The recorded state has not come back yet: the states read are empty.
    container.invalidate(homeCardsProvider);
    await container.read(homeCardsProvider.future);
    container.invalidate(homeCardsProvider);
    await container.read(homeCardsProvider.future);

    verify(() => cardStates.recordShown('onboarding:optional_window'))
        .called(1);
  });

  test('a slow source does not delay the loading of the others', () async {
    final slow = StreamController<List<BookedWishRemoval>>();
    addTearDown(slow.close);
    when(() => removals.watchPending()).thenAnswer((_) => slow.stream);
    when(() => friendships.getRecentlyAcceptedRequests(any())).thenAnswer(
      (_) async => [
        (
          friendId: fakeFriendUserId1,
          acceptedAt: now.subtract(const Duration(days: 1)),
        ),
      ],
    );

    final future = load();
    await pumpEventQueue();

    // Still waiting for the removals, the other sources were already asked.
    verify(() => friendships.getRecentlyAcceptedRequests(any())).called(1);

    slow.add(const []);
    final cards = await future;
    expect(cards.map((c) => c.type), ['friend_accepted']);
  });
}
