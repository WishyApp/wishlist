import 'dart:math';

import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/card_state.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/utils/occasion_wishlist_utils.dart';

// Pure functions: they build the cards that could be shown at [now] (local
// time) from data the app already has. Each returns nothing when its
// definition is null (the card type is disabled in `home_cards`). Days are
// local calendar days, counted on UTC dates so that a daylight saving change
// never shifts them.

const _optionalWindowKey = 'onboarding:optional_window';
const _birthdayStepKey = 'onboarding:birthday';
const _photoStepKey = 'onboarding:photo';

DateTime _day(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day);
}

int _daysBetween(DateTime from, DateTime to) {
  return DateTime.utc(to.year, to.month, to.day)
      .difference(DateTime.utc(from.year, from.month, from.day))
      .inDays;
}

/// Local day that is [days] after today (the next occurrence of a birthday).
DateTime _birthdayDay(DateTime today, int days) {
  return DateTime(today.year, today.month, today.day + days);
}

/// Christmas day of the next 25 December, today included.
DateTime _nextChristmas(DateTime today) {
  final thisYear = DateTime(today.year, 12, 25);
  return today.isAfter(thisYear) ? DateTime(today.year + 1, 12, 25) : thisYear;
}

int _maxReminderDays(HomeCardDefinition definition) {
  return definition.intListParam('reminder_days').fold(0, max);
}

Wishlist? _christmasWishlist(
  List<Wishlist> wishlists,
  HomeCardDefinition? christmas,
  DateTime occasionDate,
) {
  return findOccasionWishlist(
    wishlists: wishlists,
    keywords: christmas?.stringListParam('keywords') ?? const [],
    occasionDate: occasionDate,
  );
}

/// Friends whose birthday is today (`friend_birthday_today`) or within the
/// largest `reminder_days` of [soon] (`friend_birthday`). The key carries the
/// year of the next occurrence: on December 20 a birthday on January 3 is the
/// one of next year, and hiding it now does not hide it then.
List<HomeCardCandidate> friendBirthdayCards({
  required List<AppUser> friends,
  required Map<String, Birthday> birthdays,
  required HomeCardDefinition? today,
  required HomeCardDefinition? soon,
  required DateTime now,
}) {
  final todayDay = _day(now);
  final cards = <HomeCardCandidate>[];
  for (final friend in friends) {
    final birthday = birthdays[friend.user.id];
    if (birthday == null) {
      continue;
    }
    final days = birthday.daysUntil(now);
    final eventDay = _birthdayDay(todayDay, days);
    final id = friend.user.id;
    if (days == 0) {
      if (today != null) {
        cards.add(
          HomeCardCandidate(
            type: today.key,
            stateKey: cardKey(today.key, id: id, year: eventDay.year),
            content: FriendBirthdayToday(friend),
            tone: HomeCardTone.highlighted,
            eventAt: eventDay,
          ),
        );
      }
    } else if (soon != null && days <= _maxReminderDays(soon)) {
      cards.add(
        HomeCardCandidate(
          type: soon.key,
          stateKey: cardKey(soon.key, id: id, year: eventDay.year),
          content: FriendBirthdaySoon(friend, birthday, days),
          tone: soon.isHighlighted(eventOn: eventDay, now: now)
              ? HomeCardTone.highlighted
              : HomeCardTone.light,
          eventAt: eventDay,
        ),
      );
    }
  }
  return cards;
}

/// The day after the user's birthday or after Christmas, up to `days_after`
/// days. The wishlist of Christmas is found by its name; the one of the
/// birthday is the only wishlist, if there is just one.
List<HomeCardCandidate> afterPartyCards({
  required Birthday? myBirthday,
  required List<Wishlist> wishlists,
  required HomeCardDefinition? definition,
  required HomeCardDefinition? christmas,
  required DateTime now,
}) {
  if (definition == null) {
    return const [];
  }
  final today = _day(now);
  final daysAfter = definition.intParam('days_after', 7);
  final cards = <HomeCardCandidate>[];

  if (myBirthday != null) {
    for (var ago = 1; ago <= daysAfter; ago++) {
      final day = DateTime(today.year, today.month, today.day - ago);
      // Reuses the rule of the birthday (February 29 in a common year).
      if (myBirthday.daysUntil(day) == 0) {
        cards.add(
          HomeCardCandidate(
            type: definition.key,
            stateKey: cardKey(definition.key, id: 'birthday', year: day.year),
            content: AfterParty(
              AfterPartyOccasion.birthday,
              ago,
              wishlists.length == 1 ? wishlists.single : null,
            ),
            eventAt: day,
          ),
        );
        break;
      }
    }
  }

  for (final year in [today.year, today.year - 1]) {
    final christmasDay = DateTime(year, 12, 25);
    final ago = _daysBetween(christmasDay, today);
    if (ago >= 1 && ago <= daysAfter) {
      cards.add(
        HomeCardCandidate(
          type: definition.key,
          stateKey: cardKey(definition.key, id: 'christmas', year: year),
          content: AfterParty(
            AfterPartyOccasion.christmas,
            ago,
            _christmasWishlist(wishlists, christmas, christmasDay),
          ),
          eventAt: christmasDay,
        ),
      );
      break;
    }
  }
  return cards;
}

/// Wishes still to give whose owner has their birthday, or Christmas comes,
/// within `days_before` days. The closest occasion wins, the birthday on a tie.
/// The key carries the occasion.
List<HomeCardCandidate> bookedReminderCards({
  required List<BookedWishWithDetails> bookings,
  required Map<String, Birthday> birthdays,
  required HomeCardDefinition? definition,
  required DateTime now,
}) {
  if (definition == null) {
    return const [];
  }
  final today = _day(now);
  final daysBefore = definition.intParam('days_before', 14);
  final christmasDay = _nextChristmas(today);
  final christmasDays = _daysBetween(today, christmasDay);
  final cards = <HomeCardCandidate>[];

  for (final booking in bookings) {
    if (booking.isGiven) {
      continue;
    }
    final birthday = birthdays[booking.ownerId];
    final birthdayDays = birthday?.daysUntil(now);

    ReminderOccasion? occasion;
    int? days;
    if (birthdayDays != null && birthdayDays <= daysBefore) {
      occasion = ReminderOccasion.ownerBirthday;
      days = birthdayDays;
    }
    if (christmasDays <= daysBefore && (days == null || christmasDays < days)) {
      occasion = ReminderOccasion.christmas;
      days = christmasDays;
    }
    if (occasion == null || days == null) {
      continue;
    }
    final eventDay = occasion == ReminderOccasion.christmas
        ? christmasDay
        : _birthdayDay(today, days);
    final occasionName =
        occasion == ReminderOccasion.christmas ? 'christmas' : 'birthday';
    cards.add(
      HomeCardCandidate(
        type: definition.key,
        // One reminder per party: hiding the birthday one leaves the
        // Christmas one of the same wish.
        stateKey: cardKey(
          definition.key,
          id: '${booking.wish.id}-$occasionName',
          year: eventDay.year,
        ),
        content: BookedReminder(booking, occasion, days),
        eventAt: eventDay,
      ),
    );
  }
  return cards;
}

/// One alert per wish a friend removed after the user booked it.
List<HomeCardCandidate> bookedWishRemovedCards({
  required List<BookedWishRemoval> removals,
  required HomeCardDefinition? definition,
}) {
  if (definition == null) {
    return const [];
  }
  return [
    for (final removal in removals)
      HomeCardCandidate(
        type: definition.key,
        stateKey: cardKey(definition.key, id: removal.id),
        content: BookedWishRemoved(removal),
        eventAt: removal.removedAt,
      ),
  ];
}

/// Friends who accepted the user's request at most `days` days ago.
List<HomeCardCandidate> friendAcceptedCards({
  required List<({AppUser friend, DateTime acceptedAt})> accepted,
  required HomeCardDefinition? definition,
  required DateTime now,
}) {
  if (definition == null) {
    return const [];
  }
  final window = Duration(days: definition.intParam('days', 7));
  return [
    for (final request in accepted)
      if (now.difference(request.acceptedAt) <= window)
        HomeCardCandidate(
          type: definition.key,
          stateKey: cardKey(definition.key, id: request.friend.user.id),
          content: FriendAccepted(request.friend, request.acceptedAt),
          eventAt: request.acceptedAt,
        ),
  ];
}

/// From the largest `reminder_days` before Christmas to the day itself.
List<HomeCardCandidate> christmasCards({
  required List<Wishlist> wishlists,
  required HomeCardDefinition? definition,
  required DateTime now,
}) {
  if (definition == null) {
    return const [];
  }
  final today = _day(now);
  final christmasDay = _nextChristmas(today);
  final days = _daysBetween(today, christmasDay);
  if (days > _maxReminderDays(definition)) {
    return const [];
  }
  return [
    HomeCardCandidate(
      type: definition.key,
      stateKey: cardKey(definition.key, year: christmasDay.year),
      content: Christmas(
        days,
        _christmasWishlist(wishlists, definition, christmasDay),
      ),
      tone: definition.isHighlighted(eventOn: christmasDay, now: now)
          ? HomeCardTone.highlighted
          : HomeCardTone.light,
      eventAt: christmasDay,
    ),
  ];
}

/// One card that moves from step to step: first wishlist, first friend (not
/// dismissable; [friendCount] counts friends and requests the user sent),
/// then birthday and photo. The optional steps are dismissed for good by a
/// swipe, and end `optional_steps_hours` hours after
/// `onboarding:optional_window` was first shown.
List<HomeCardCandidate> onboardingCards({
  required int wishlistCount,
  required int friendCount,
  required bool hasBirthday,
  required bool hasAvatar,
  required Map<String, CardState> states,
  required HomeCardDefinition? definition,
  required DateTime now,
}) {
  if (definition == null) {
    return const [];
  }

  HomeCardCandidate card(OnboardingStep step, {required bool dismissable}) {
    return HomeCardCandidate(
      type: definition.key,
      stateKey: cardKey(definition.key, id: step.name),
      content: Onboarding(step),
      dismissable: dismissable,
    );
  }

  if (wishlistCount == 0) {
    return [card(OnboardingStep.firstWishlist, dismissable: false)];
  }
  if (friendCount == 0) {
    return [card(OnboardingStep.firstFriend, dismissable: false)];
  }

  final windowStart = states[_optionalWindowKey]?.lastShownAt;
  final windowHours = definition.intParam('optional_steps_hours', 48);
  if (windowStart != null &&
      now.difference(windowStart) >= Duration(hours: windowHours)) {
    return const [];
  }
  bool isHidden(String key) => states[key]?.isHidden(now) ?? false;
  if (!hasBirthday && !isHidden(_birthdayStepKey)) {
    return [card(OnboardingStep.birthday, dismissable: true)];
  }
  if (!hasAvatar && !isHidden(_photoStepKey)) {
    return [card(OnboardingStep.photo, dismissable: true)];
  }
  return const [];
}

/// When a card dismissed with "Hide" at [now] comes back: the next reminder
/// step for a friend birthday or Christmas, null (never) for the others.
DateTime? hideUntil(
  HomeCardCandidate card,
  Map<String, HomeCardDefinition> definitions,
  DateTime now,
) {
  final eventAt = card.eventAt;
  if (eventAt == null ||
      (card.type != 'friend_birthday' && card.type != 'christmas')) {
    return null;
  }
  return definitions[card.type]?.nextReminderAfter(
    eventOn: eventAt,
    dismissedAt: now,
  );
}
