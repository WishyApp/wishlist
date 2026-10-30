import 'package:flutter/foundation.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

/// How a card looks: white with an orange button, orange for what is close,
/// dark for the yearly recap.
enum HomeCardTone { light, highlighted, dark }

enum AfterPartyOccasion { birthday, christmas }

enum ReminderOccasion { ownerBirthday, christmas }

/// The steps of the onboarding card, in the order they are offered. The name
/// is the last part of the card key (`onboarding:birthday`).
enum OnboardingStep { firstWishlist, firstFriend, birthday, photo }

/// What a card shows: one subclass per card type.
@immutable
sealed class HomeCardContent {
  const HomeCardContent();
}

final class FriendBirthdayToday extends HomeCardContent {
  const FriendBirthdayToday(this.friend);

  final AppUser friend;
}

final class FriendBirthdaySoon extends HomeCardContent {
  const FriendBirthdaySoon(this.friend, this.birthday, this.days);

  final AppUser friend;
  final Birthday birthday;

  /// Whole days left, at least 1.
  final int days;
}

final class AfterParty extends HomeCardContent {
  const AfterParty(
    this.occasion,
    this.daysAgo,
    this.wishlist, {
    required this.partyDay,
  });

  final AfterPartyOccasion occasion;
  final int daysAgo;

  /// The day of the party (local midnight): December 25 or the birthday.
  final DateTime partyDay;

  /// The wishlist of the occasion, if it could be told which one.
  final Wishlist? wishlist;
}

final class BookedReminder extends HomeCardContent {
  const BookedReminder(this.booking, this.occasion, this.days);

  final BookedWishWithDetails booking;
  final ReminderOccasion occasion;
  final int days;
}

final class BookedWishRemoved extends HomeCardContent {
  const BookedWishRemoved(this.removal, {required this.canOpenList});

  /// Carries the pseudo of the owner (empty when they had none).
  final BookedWishRemoval removal;

  /// Whether the owner's list can still be opened: the user is still their
  /// friend and the wishlist is open. Otherwise the card only informs.
  final bool canOpenList;
}

final class FriendAccepted extends HomeCardContent {
  const FriendAccepted(this.friend, this.acceptedAt);

  final AppUser friend;
  final DateTime acceptedAt;
}

final class Christmas extends HomeCardContent {
  const Christmas(this.days, this.wishlist);

  final int days;
  final Wishlist? wishlist;
}

final class Onboarding extends HomeCardContent {
  const Onboarding(this.step);

  final OnboardingStep step;
}

final class StaleWishlist extends HomeCardContent {
  const StaleWishlist(this.wishlist, this.monthsIdle);

  final Wishlist wishlist;

  /// Whole months (of 30 days) without activity.
  final int monthsIdle;
}

final class YearRecap extends HomeCardContent {
  const YearRecap(this.recap);

  final YearRecapData recap;
}

/// A card that could be shown now, before the user's states and the stack
/// size are applied.
@immutable
class HomeCardCandidate {
  const HomeCardCandidate({
    required this.type,
    required this.stateKey,
    required this.content,
    this.tone = HomeCardTone.light,
    this.eventAt,
    this.lastDay,
    this.dismissable = true,
    this.maxShows,
  });

  /// Key of the `home_cards` row that tunes this card.
  final String type;

  /// Key of the card in `user_card_states` (see `cardKey`).
  final String stateKey;
  final HomeCardContent content;
  final HomeCardTone tone;

  /// The day of the occasion, to sort cards of the same priority.
  final DateTime? eventAt;

  /// The last local day the card is still built, null when there is no end in
  /// sight. A card that would be gone by the day it is postponed to is not
  /// offered "Later": it would act as a hide.
  final DateTime? lastDay;

  /// False when the card cannot be hidden (the first onboarding steps).
  final bool dismissable;

  /// The card is dropped once it was shown this many times.
  final int? maxShows;
}
