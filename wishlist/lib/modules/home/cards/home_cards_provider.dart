import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/home/cards/card_builders.dart';
import 'package:wishlist/modules/home/cards/card_selection.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
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
  final now = ref.watch(clockProvider)();
  _recomputeOnNewDay(ref, now);
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
void _recomputeOnNewDay(Ref ref, DateTime now) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final midnight = DateTime(today.year, today.month, today.day + 1);
  final timer = Timer(midnight.difference(local), ref.invalidateSelf);
  final lifecycle = AppLifecycleListener(
    onResume: () {
      final current = ref.read(clockProvider)().toLocal();
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
  final cardStateRepository = ref.watch(cardStateRepositoryProvider);
  final friendshipRepository = ref.watch(friendshipRepositoryProvider);

  // Everything is loaded at once: the cards wait for the slowest source, not
  // for the sum of them. The loads of the sources that only feed some cards
  // cannot fail (`_orElse`): a failure loses just those cards.
  final definitionsFuture = ref.watch(homeCardDefinitionsProvider.future);
  // The providers below are live streams: only a slice of each is watched
  // (ids, names, flags), the objects themselves are then read once.
  final wishlistsFuture = () async {
    await ref.watch(
      wishlistsRealtimeProvider.selectAsync(
        (list) => [for (final w in list) (id: w.id, name: w.name)].toIList(),
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
              (wishId: b.wish.id, ownerId: b.ownerId, isGiven: b.isGiven),
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

  final (
    definitions,
    wishlists,
    friendsData,
    birthdays,
    bookings,
    removals,
    accepted,
    myBirthdayState,
    hasAvatar,
  ) = await (
    definitionsFuture,
    wishlistsFuture,
    friendsDataFuture,
    birthdaysFuture,
    bookingsFuture,
    removalsFuture,
    acceptedFuture,
    myBirthdayFuture,
    hasAvatarFuture,
  ).wait;
  final friends = friendsData?.friends ?? const IListConst<AppUser>([]);
  final sentRequests = friendsData?.pendingFriends.length ?? 0;
  final myBirthday = myBirthdayState.birthday;
  final hasBirthday = !myBirthdayState.known || myBirthday != null;

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
  ];

  // The onboarding card needs the states of its optional steps, which are
  // fetched with the others in one go.
  final states = await cardStateRepository.getStates([
    for (final candidate in candidates) candidate.stateKey,
    ..._onboardingStateKeys,
  ]);
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
      ref.read(_optionalWindowRecordedProvider).add(userId)) {
    unawaited(
      _recordOptionalWindow(
        cardStateRepository,
        () => ref.read(_optionalWindowRecordedProvider).remove(userId),
      ),
    );
  }
  return cards;
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
