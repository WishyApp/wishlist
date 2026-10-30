import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/home/cards/card_builders.dart';
import 'package:wishlist/modules/home/cards/card_selection.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/wishlists_last_activity_provider.dart';
import 'package:wishlist/modules/home/cards/year_recap_provider.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/home_card/home_card_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_repository_provider.dart';
import 'package:wishlist/shared/infra/visible_birthdays_provider.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

const _stackKey = 'home_stack';
const _defaultMaxCards = 3;
const _onboardingStateKeys = [
  onboardingOptionalWindowKey,
  onboardingBirthdayKey,
  onboardingPhotoKey,
];

/// Alerts about booked wishes the owner removed, not dismissed yet.
final pendingBookedWishRemovalsProvider =
    StreamProvider.autoDispose<List<BookedWishRemoval>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    // Signed out: an empty value replaces the previous user's one.
    return Stream.value(const []);
  }
  return ref.watch(bookedWishRemovalRepositoryProvider).watchPending();
});

/// The `home_cards` rows by key. Its own provider so that the live data the
/// cards depend on never refetches the table.
final homeCardDefinitionsProvider =
    FutureProvider.autoDispose<Map<String, HomeCardDefinition>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) {
    return const {};
  }
  final rows = await ref.watch(homeCardRepositoryProvider).getActiveCards();
  return {for (final definition in rows) definition.key: definition};
});

/// The cards of the moment to show on the home screen, most urgent first.
///
/// The slot that shows it must render the previous value while it reloads
/// (`valueOrNull`, or `skipLoadingOnReload`), so that the pile never blinks.
/// It only reloads when a slice the cards are built from changes (ids, names,
/// counts, flags), not on every live event: the full objects are read without
/// watching them.
///
/// Cards are a bonus: the stack is empty, and the home screen still renders,
/// when what decides them cannot be loaded (`home_cards`, card states,
/// wishlists, friends). A source that only feeds some cards (birthdays,
/// bookings, alerts, recent friends) loses just those cards.
final homeCardsProvider =
    FutureProvider.autoDispose<List<HomeCardCandidate>>((ref) async {
  final clock = ref.watch(clockProvider);
  final now = clock();
  _recomputeOnNewDay(ref, clock, now);
  try {
    return await _loadCards(ref, now);
  } catch (e) {
    debugPrint('[Wishy home cards] load failed, showing none: $e');
    return const [];
  }
});

/// The cards depend on the local day: recompute at the next midnight, and when
/// the app comes back to the foreground on another day than the one the cards
/// were computed for (timers do not run while it sleeps).
void _recomputeOnNewDay(Ref ref, DateTime Function() clock, DateTime now) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final midnight = DateTime(today.year, today.month, today.day + 1);
  final timer = Timer(midnight.difference(local), ref.invalidateSelf);
  final lifecycle = AppLifecycleListener(
    onResume: () {
      final current = clock().toLocal();
      if (DateTime(current.year, current.month, current.day) != today) {
        ref.invalidateSelf();
      }
    },
  );
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
  });
}

/// The users whose start of the onboarding window was recorded since the app
/// started: recomputes close to each other all see no state yet.
final _optionalWindowRecordedProvider = Provider<Set<String>>((ref) => {});

Future<List<HomeCardCandidate>> _loadCards(Ref ref, DateTime now) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const [];
  }
  // Captured here: callbacks run outside the build, where `ref` must not be
  // used to read.
  final recordedWindows = ref.watch(_optionalWindowRecordedProvider);
  final cardStateRepository = ref.watch(cardStateRepositoryProvider);
  final friendshipRepository = ref.watch(friendshipRepositoryProvider);
  final wishlistRepository = ref.watch(wishlistRepositoryProvider);

  // Everything is loaded at once: the cards wait for the slowest source, not
  // for the sum of them. The loads of the sources that only feed some cards
  // cannot fail (`_orElse`): a failure loses just those cards.
  final definitionsFuture = ref.watch(homeCardDefinitionsProvider.future);
  // The providers below are live streams: only a slice of each is watched
  // (ids, names, flags), the objects themselves are then read once.
  final wishlistsFuture = () async {
    await ref.watch(
      wishlistsRealtimeProvider.selectAsync(
        (list) => [
          for (final w in list)
            (id: w.id, name: w.name, owner: w.idOwner, isClosed: w.isClosed),
        ].toIList(),
      ),
    );
    return _valueOf(wishlistsRealtimeProvider, ref) ?? const <Wishlist>[];
  }();
  final friendsDataFuture = () async {
    await ref.watch(
      friendshipsRealtimeProvider.selectAsync(
        (data) => (
          [for (final f in data.friends) f.user.id].toIList(),
          [for (final f in data.pendingFriends) f.user.id].toIList(),
        ),
      ),
    );
    return _valueOf(friendshipsRealtimeProvider, ref);
  }();
  final birthdaysFuture = _orElse<Map<String, Birthday>>(
    'friends birthdays',
    () async => (await ref.watch(visibleBirthdaysProvider.future)).birthdays,
    const <String, Birthday>{},
  );
  final bookingsFuture = _orElse<List<BookedWishWithDetails>>(
    'booked wishes',
    () async {
      await ref.watch(
        bookedWishesRealtimeProvider.selectAsync(
          (list) => [
            for (final b in list)
              (
                wishId: b.wish.id,
                ownerId: b.ownerId,
                isGiven: b.isGiven,
                wishlistName: b.wishlistName,
              ),
          ].toIList(),
        ),
      );
      return _valueOf(bookedWishesRealtimeProvider, ref)?.toList() ?? const [];
    },
    const <BookedWishWithDetails>[],
  );
  final removalsFuture = _orElse<List<BookedWishRemoval>>(
    'booked wish removals',
    () async {
      await ref.watch(
        pendingBookedWishRemovalsProvider.selectAsync(
          (list) => [for (final r in list) r.id].toIList(),
        ),
      );
      return _valueOf(pendingBookedWishRemovalsProvider, ref) ?? const [];
    },
    const <BookedWishRemoval>[],
  );
  // The owner's list is only offered while the user is still their friend and
  // the wishlist is open: their public wishlists are fetched for that, a
  // failure leaves only the alerts of that owner without the button.
  final removalsWithListFuture = () async {
    final removals = await removalsFuture;
    if (removals.isEmpty) {
      return (removals: removals, withList: const <int>{});
    }
    final withList = await _orElse<Set<int>>(
      'removed wishes lists',
      () async {
        final friends =
            (await friendsDataFuture)?.friends ?? const IListConst<AppUser>([]);
        return _loadRemovalsWithOpenList(
          wishlistRepository.getPublicWishlistsByUser,
          removals,
          {for (final friend in friends) friend.user.id},
          now,
        );
      },
      const <int>{},
    );
    return (removals: removals, withList: withList);
  }();
  final acceptedFuture = _orElse<List<({AppUser friend, DateTime acceptedAt})>>(
    'accepted requests',
    () async {
      final friends = (await friendsDataFuture)?.friends;
      if (friends == null || friends.isEmpty) {
        return const [];
      }
      return _loadAccepted(
        friendshipRepository.getRecentlyAcceptedRequests,
        friends,
        (await definitionsFuture)['friend_accepted'],
        now,
      );
    },
    const <({AppUser friend, DateTime acceptedAt})>[],
  );
  // When the birthday or the photo cannot be read, it is taken as set: better
  // no card than asking for something the user may have done.
  final myBirthdayFuture = _orElse<({bool known, Birthday? birthday})>(
    'my birthday',
    () async => (
      known: true,
      birthday: await ref.watch(currentUserBirthdayProvider.future),
    ),
    (known: false, birthday: null),
  );
  final hasAvatarFuture = _orElse<bool>(
    'my photo',
    () => ref.watch(
      watchCurrentUserProfileProvider.selectAsync(
        (profile) => profile?.avatarUrl?.isNotEmpty ?? false,
      ),
    ),
    true,
  );

  // The two slow reads only depend on the definitions (and the wishlists):
  // they start as soon as those are there, in parallel with the sources
  // above, and are awaited after them (a record `.wait` takes 9 futures at
  // most). Their failure is caught here, it only loses their cards. The last
  // activity has its own provider, so that a reload of the cards (swipe,
  // booking change) does not ask it again.
  final lastActivityFuture = _orElse<Map<int, DateTime>>(
    'wishlists last activity',
    () async {
      final definitions = await definitionsFuture;
      final wishlists = await wishlistsFuture;
      return definitions['stale_wishlist'] == null || wishlists.isEmpty
          ? const <int, DateTime>{}
          : await ref.watch(wishlistsLastActivityProvider.future);
    },
    const <int, DateTime>{},
  );
  // The recap reads the received wishes once, and only in its month: nothing
  // heavy is kept alive the rest of the year.
  final yearRecapFuture = _orElse<YearRecapFacts?>(
    'year recap',
    () async {
      final definitions = await definitionsFuture;
      return !isYearRecapMonth(definitions['year_recap'], now)
          ? null
          : await ref.watch(yearRecapFactsProvider(now.toLocal().year).future);
    },
    null,
  );

  final (
    definitions,
    wishlists,
    friendsData,
    birthdays,
    bookings,
    (:removals, withList: removalsWithList),
    accepted,
    myBirthdayState,
    hasAvatar,
  ) = await (
    definitionsFuture,
    wishlistsFuture,
    friendsDataFuture,
    birthdaysFuture,
    bookingsFuture,
    removalsWithListFuture,
    acceptedFuture,
    myBirthdayFuture,
    hasAvatarFuture,
  ).wait;
  final friends = friendsData?.friends ?? const IListConst<AppUser>([]);
  final sentRequests = friendsData?.pendingFriends.length ?? 0;
  final myBirthday = myBirthdayState.birthday;
  final hasBirthday = !myBirthdayState.known || myBirthday != null;
  final lastActivity = await lastActivityFuture;
  final yearRecap = await yearRecapFuture;

  final candidates = [
    ...friendBirthdayCards(
      friends: friends.toList(),
      birthdays: birthdays,
      today: definitions['friend_birthday_today'],
      soon: definitions['friend_birthday'],
      now: now,
    ),
    ...afterPartyCards(
      myBirthday: myBirthday,
      wishlists: wishlists,
      userId: userId,
      definition: definitions['after_party'],
      christmas: definitions['christmas'],
      now: now,
    ),
    ...bookedReminderCards(
      bookings: bookings,
      birthdays: birthdays,
      definition: definitions['booked_reminder'],
      christmas: definitions['christmas'],
      now: now,
    ),
    ...bookedWishRemovedCards(
      removals: removals,
      definition: definitions['booked_wish_removed'],
      withOpenList: removalsWithList,
    ),
    ...friendAcceptedCards(
      accepted: accepted,
      definition: definitions['friend_accepted'],
      now: now,
    ),
    ...christmasCards(
      wishlists: wishlists,
      userId: userId,
      definition: definitions['christmas'],
      now: now,
    ),
    if (yearRecap != null)
      ...yearRecapCards(
        facts: yearRecap,
        definition: definitions['year_recap'],
        now: now,
      ),
  ];

  // The onboarding card needs the states of its optional steps, which are
  // fetched with the others in one go.
  // The stale lists too: the oldest one whose card is not snoozed is kept.
  final staleCandidates = staleWishlistCandidates(
    wishlists: wishlists,
    lastActivity: lastActivity,
    definition: definitions['stale_wishlist'],
    now: now,
  );
  final states = await cardStateRepository.getStates([
    for (final candidate in candidates) candidate.stateKey,
    for (final candidate in staleCandidates) candidate.stateKey,
    ..._onboardingStateKeys,
  ]);
  candidates.addAll(
    staleWishlistCards(
      candidates: staleCandidates,
      states: states,
      now: now,
    ),
  );
  candidates.addAll(
    onboardingCards(
      wishlistCount: wishlists.length,
      // A request already sent is as good as a friend for step 2.
      friendCount: friends.length + sentRequests,
      hasBirthday: hasBirthday,
      hasAvatar: hasAvatar,
      states: states,
      definition: definitions['onboarding'],
      now: now,
    ),
  );

  final cards = selectHomeCards(
    candidates: candidates,
    definitions: definitions,
    states: states,
    maxCards: definitions[_stackKey]?.intParam('max_cards', _defaultMaxCards) ??
        _defaultMaxCards,
    now: now,
  );

  // The optional onboarding steps stop 48 hours after they were first shown.
  // Only the top card is really in front of the user: record the start of the
  // window then, once. Nothing else may ever record this key, its
  // `lastShownAt` is the start of the window.
  final top = cards.firstOrNull?.content;
  if (top is Onboarding &&
      (top.step == OnboardingStep.birthday ||
          top.step == OnboardingStep.photo) &&
      !states.containsKey(onboardingOptionalWindowKey) &&
      recordedWindows.add(userId)) {
    unawaited(
      _recordOptionalWindow(
        cardStateRepository,
        () => recordedWindows.remove(userId),
      ),
    );
  }
  return cards;
}

Future<Set<int>> _loadRemovalsWithOpenList(
  Future<IList<Wishlist>> Function(String) load,
  List<BookedWishRemoval> removals,
  Set<String> friendIds,
  DateTime now,
) async {
  final owners = {
    for (final removal in removals)
      if (friendIds.contains(removal.ownerId)) removal.ownerId,
  };
  // In parallel, and an owner whose wishlists cannot be loaded is simply
  // missing: their alerts lose the button, the others keep it.
  final loaded = await Future.wait([
    for (final owner in owners)
      () async {
        try {
          return MapEntry(owner, (await load(owner)).toList());
        } catch (e) {
          debugPrint('[Wishy home cards] wishlists of $owner failed: $e');
          return null;
        }
      }(),
  ]);
  final wishlists = {
    for (final entry in loaded)
      if (entry != null) entry.key: entry.value,
  };
  return removalsWithOpenList(
    removals: removals,
    friendIds: friendIds,
    publicWishlists: wishlists,
    now: now,
  );
}

Future<List<({AppUser friend, DateTime acceptedAt})>> _loadAccepted(
  Future<List<({String friendId, DateTime acceptedAt})>> Function(DateTime)
      load,
  Iterable<AppUser> friends,
  HomeCardDefinition? definition,
  DateTime now,
) async {
  if (definition == null) {
    return const [];
  }
  final since = now.subtract(Duration(days: definition.intParam('days', 7)));
  final friendsById = {for (final friend in friends) friend.user.id: friend};
  return [
    for (final request in await load(since))
      // A friend removed since then has no card.
      if (friendsById[request.friendId] case final friend?)
        (friend: friend, acceptedAt: request.acceptedAt),
  ];
}

Future<T> _orElse<T>(
  String what,
  Future<T> Function() load,
  T fallback,
) async {
  try {
    return await load();
  } catch (e) {
    debugPrint('[Wishy home cards] $what failed, skipping its cards: $e');
    return fallback;
  }
}

/// Fire and forget: the window is a nicety, its failure must not touch the
/// stack.
Future<void> _recordOptionalWindow(
  CardStateRepository repository,
  void Function() onFailure,
) async {
  try {
    await repository.recordShown(onboardingOptionalWindowKey);
  } catch (e) {
    // A later recompute may try again.
    onFailure();
    debugPrint('[Wishy home cards] could not record the window: $e');
  }
}

T? _valueOf<T>(ProviderListenable<AsyncValue<T>> provider, Ref ref) {
  return ref.read(provider).valueOrNull;
}
