import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// The cards of the moment to show on the home screen, most urgent first.
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
  if (ref.watch(currentUserIdProvider) == null) {
    return const [];
  }
  final now = ref.watch(clockProvider)();
  final cardRepository = ref.watch(homeCardRepositoryProvider);
  final cardStateRepository = ref.watch(cardStateRepositoryProvider);
  final friendshipRepository = ref.watch(friendshipRepositoryProvider);

  final definitions = {
    for (final definition in await cardRepository.getActiveCards())
      definition.key: definition,
  };
  final wishlists = await ref.watch(wishlistsRealtimeProvider.future);
  final friends = (await ref.watch(friendshipsRealtimeProvider.future)).friends;

  // Each of these only feeds some cards: a failure loses just those.
  final birthdays = await _orElse<Map<String, Birthday>>(
    'friends birthdays',
    () async => (await ref.watch(visibleBirthdaysProvider.future)).birthdays,
    const <String, Birthday>{},
  );
  final bookings = await _orElse<List<BookedWishWithDetails>>(
    'booked wishes',
    () async => (await ref.watch(bookedWishesRealtimeProvider.future)).toList(),
    const <BookedWishWithDetails>[],
  );
  final removals = await _orElse<List<BookedWishRemoval>>(
    'booked wish removals',
    () => ref.watch(pendingBookedWishRemovalsProvider.future),
    const <BookedWishRemoval>[],
  );
  final accepted = await _orElse<List<({AppUser friend, DateTime acceptedAt})>>(
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
    () async {
      final profile = await ref.watch(watchCurrentUserProfileProvider.future);
      return profile?.avatarUrl?.isNotEmpty ?? false;
    },
    true,
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
      friendCount: friends.length,
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

  // The optional onboarding steps stop 48 hours after they were first
  // offered: note that moment once.
  final offersOptionalStep = cards.any((card) {
    final content = card.content;
    return content is Onboarding &&
        (content.step == OnboardingStep.birthday ||
            content.step == OnboardingStep.photo);
  });
  if (offersOptionalStep && !states.containsKey(_optionalWindowKey)) {
    unawaited(_recordOptionalWindow(cardStateRepository));
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
Future<void> _recordOptionalWindow(CardStateRepository repository) async {
  try {
    await repository.recordShown(_optionalWindowKey);
  } catch (e) {
    debugPrint('[Wishy home cards] could not record the window: $e');
  }
}
