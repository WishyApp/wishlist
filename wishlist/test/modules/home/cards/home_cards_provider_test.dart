import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/home_card/home_card_repository.dart';
import 'package:wishlist/shared/infra/repositories/home_card/home_card_repository_provider.dart';
import 'package:wishlist/shared/infra/visible_birthdays_provider.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';
import 'package:wishlist/shared/models/card_state.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';
import 'package:wishlist/shared/models/profile.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';

class MockHomeCardRepository extends Mock implements HomeCardRepository {}

class MockCardStateRepository extends Mock implements CardStateRepository {}

class MockBookedWishRemovalRepository extends Mock
    implements BookedWishRemovalRepository {}

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
];

void main() {
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

  Future<List<HomeCardCandidate>> load({
    DateTime? at,
    Map<String, Birthday> birthdays = const {},
    Birthday? myBirthday = const Birthday(month: 1, day: 1),
    bool hasAvatar = true,
    List<Override> extra = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        ...homeScreenOverrides(
          birthdays: birthdays,
          now: at ?? now,
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
    return container.read(homeCardsProvider.future);
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
      ['friend_accepted:$fakeFriendUserId1'],
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
}
