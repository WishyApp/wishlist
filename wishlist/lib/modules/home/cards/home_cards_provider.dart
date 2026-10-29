import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/home/cards/card_builders.dart';
import 'package:wishlist/modules/home/cards/card_selection.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
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
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

const _stackKey = 'home_stack';
const _defaultMaxCards = 3;
const _optionalWindowKey = 'onboarding:optional_window';
const _onboardingStateKeys = [
  _optionalWindowKey,
  'onboarding:birthday',
  'onboarding:photo',
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
  try {
    return await _loadCards(ref);
  } catch (e) {
    debugPrint('[Wishy home cards] load failed, showing none: $e');
    return const [];
  }
});

Future<List<HomeCardCandidate>> _loadCards(Ref ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const [];
  }
  final now = ref.watch(clockProvider)();
  final cardStateRepository = ref.watch(cardStateRepositoryProvider);
  final friendshipRepository = ref.watch(friendshipRepositoryProvider);
  final wishlistRepository = ref.watch(wishlistRepositoryProvider);

  final definitions = await ref.watch(homeCardDefinitionsProvider.future);
  // The providers below are live streams: only a slice of each is watched
  // (ids, names, flags), the objects themselves are then read once.
  await ref.watch(
    wishlistsRealtimeProvider.selectAsync(
      (list) => [
        for (final w in list)
          (id: w.id, name: w.name, owner: w.idOwner, isClosed: w.isClosed),
      ].toIList(),
    ),
  );
  final wishlists = _valueOf(wishlistsRealtimeProvider, ref) ?? const [];
  // Started now and awaited with the stale card: it runs in parallel with the
  // sources below. Its failure is caught here, it only loses that card.
  final lastActivityFuture = _orElse<Map<int, DateTime>>(
    'wishlists last activity',
    () => definitions['stale_wishlist'] == null || wishlists.isEmpty
        ? Future.value(const <int, DateTime>{})
        : wishlistRepository.getLastActivityByWishlist(),
    const <int, DateTime>{},
  );
  await ref.watch(
    friendshipsRealtimeProvider.selectAsync(
      (data) => (
        [for (final f in data.friends) f.user.id].toIList(),
        [for (final f in data.pendingFriends) f.user.id].toIList(),
      ),
    ),
  );
  final friendsData = _valueOf(friendshipsRealtimeProvider, ref);
  final friends = friendsData?.friends ?? const IListConst<AppUser>([]);
  final sentRequests = friendsData?.pendingFriends.length ?? 0;

  // Each of these only feeds some cards: a failure loses just those.
  final birthdays = await _orElse<Map<String, Birthday>>(
    'friends birthdays',
    () async => (await ref.watch(visibleBirthdaysProvider.future)).birthdays,
    const <String, Birthday>{},
  );
  final bookings = await _orElse<List<BookedWishWithDetails>>(
    'booked wishes',
    () async {
      await ref.watch(
        bookedWishesRealtimeProvider.selectAsync(
          (list) => [
            for (final b in list)
              (wishId: b.wish.id, ownerId: b.ownerId, isGiven: b.isGiven),
          ].toIList(),
        ),
      );
      return _valueOf(bookedWishesRealtimeProvider, ref)?.toList() ?? const [];
    },
    const <BookedWishWithDetails>[],
  );
  final removals = await _orElse<List<BookedWishRemoval>>(
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
  final removalsWithList = removals.isEmpty
      ? const <int>{}
      : await _orElse<Set<int>>(
          'removed wishes lists',
          () => _loadRemovalsWithOpenList(
            wishlistRepository.getPublicWishlistsByUser,
            removals,
            {for (final friend in friends) friend.user.id},
            now,
          ),
          const <int>{},
        );
  final accepted = friends.isEmpty
      ? const <({AppUser friend, DateTime acceptedAt})>[]
      : await _orElse<List<({AppUser friend, DateTime acceptedAt})>>(
          'accepted requests',
          () => _loadAccepted(
            friendshipRepository.getRecentlyAcceptedRequests,
            friends,
            definitions['friend_accepted'],
            now,
          ),
          const <({AppUser friend, DateTime acceptedAt})>[],
        );

  // When the birthday or the photo cannot be read, it is taken as set: better
  // no card than asking for something the user may have done.
  var hasBirthday = true;
  final myBirthday = await _orElse<Birthday?>(
    'my birthday',
    () async {
      final birthday = await ref.watch(currentUserBirthdayProvider.future);
      hasBirthday = birthday != null;
      return birthday;
    },
    null,
  );
  final hasAvatar = await _orElse<bool>(
    'my photo',
    () => ref.watch(
      watchCurrentUserProfileProvider.selectAsync(
        (profile) => profile?.avatarUrl?.isNotEmpty ?? false,
      ),
    ),
    true,
  );

  final lastActivity = await lastActivityFuture;
  // The recap is only loaded in its month: nothing is kept alive the rest of
  // the year.
  final yearRecap = !isYearRecapMonth(definitions['year_recap'], now)
      ? null
      : await _orElse<YearRecapData?>(
          'year recap',
          () => ref.watch(yearRecapFactsProvider(now.toLocal().year).future),
          null,
        );

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
        recap: yearRecap,
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
      wishlists: wishlists,
      lastActivity: lastActivity,
      states: states,
      definition: definitions['stale_wishlist'],
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
      !states.containsKey(_optionalWindowKey)) {
    unawaited(_recordOptionalWindow(cardStateRepository));
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
Future<void> _recordOptionalWindow(CardStateRepository repository) async {
  try {
    await repository.recordShown(_optionalWindowKey);
  } catch (e) {
    debugPrint('[Wishy home cards] could not record the window: $e');
  }
}

T? _valueOf<T>(ProviderListenable<AsyncValue<T>> provider, Ref ref) {
  return ref.read(provider).valueOrNull;
}
