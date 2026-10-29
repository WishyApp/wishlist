import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/home/cards/card_builders.dart';
import 'package:wishlist/modules/home/cards/card_selection.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/card_state.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

import '../../../fixtures/fake_data.dart';

HomeCardDefinition def(
  String key, {
  int priority = 10,
  Map<String, dynamic> params = const {},
}) {
  return HomeCardDefinition(
    key: key,
    kind: HomeCardKind.computed,
    priority: priority,
    params: params,
  );
}

final friendBirthdayToday = def('friend_birthday_today');
final friendBirthdaySoon = def(
  'friend_birthday',
  params: {
    'reminder_days': [30, 7],
    'highlight_days': 7,
  },
);
final afterPartyDef = def('after_party', params: {'days_after': 7});
final bookedReminderDef = def('booked_reminder', params: {'days_before': 14});
final removedDef = def('booked_wish_removed');
final acceptedDef = def('friend_accepted', params: {'days': 7});
final christmasDef = def(
  'christmas',
  params: {
    'reminder_days': [30, 7],
    'highlight_days': 7,
    'keywords': ['noel', 'christmas', 'xmas'],
  },
);
final staleDef = def(
  'stale_wishlist',
  params: {'stale_days': 90, 'snooze_days': 60},
);

/// A local day, for dates the analyzer would flag for their default parts.
DateTime on(int year, int month, int day) => DateTime(year, month, day);

final yearRecapDef = def('year_recap', params: {'month': 12});
final onboardingDef = def('onboarding', params: {'optional_steps_hours': 48});

Wishlist wishlist(
  int id,
  String name, {
  String owner = fakeCurrentUserId,
  bool isClosed = false,
}) {
  return Wishlist(
    id: id,
    createdAt: fakeCreatedAt,
    name: name,
    idOwner: owner,
    isClosed: isClosed,
    color: fakeColorBlue,
    canOwnerSeeTakenWish: true,
    order: 0,
    updatedBy: fakeCurrentUserId,
    updatedAt: fakeUpdatedAt,
  );
}

CompletedWishWithDetails received(
  int id, {
  required DateTime completedAt,
  DateTime? createdAt,
  String name = 'Wish',
}) {
  return CompletedWishWithDetails(
    wish: Wish(
      id: id,
      createdAt: createdAt ?? completedAt,
      name: name,
      description: '',
      quantity: 1,
      wishlistId: 1,
      updatedBy: fakeFriendUserId1,
      updatedAt: fakeUpdatedAt,
    ),
    fromWishlistId: 1,
    fromWishlistName: 'Liste',
    ownerPseudo: 'Alice',
    ownerId: fakeFriendUserId1,
    completedAt: completedAt,
    quantity: 1,
  );
}

BookedWishWithDetails offered(
  int id, {
  required DateTime? receivedAt,
  String ownerId = fakeFriendUserId1,
  String ownerPseudo = 'Alice',
}) {
  return BookedWishWithDetails(
    wish: Wish(
      id: id,
      createdAt: fakeCreatedAt,
      name: 'Wish $id',
      description: '',
      quantity: 1,
      wishlistId: 1,
      updatedBy: fakeFriendUserId1,
      updatedAt: fakeUpdatedAt,
    ),
    bookedQuantity: 1,
    wishlistName: 'Liste',
    ownerPseudo: ownerPseudo,
    ownerId: ownerId,
    receivedAt: receivedAt,
  );
}

BookedWishRemoval removal(int id, {String ownerPseudo = 'Alice'}) {
  return BookedWishRemoval(
    id: id,
    ownerId: 'owner',
    ownerPseudo: ownerPseudo,
    wishId: 40 + id,
    wishName: 'Wish $id',
    quantity: 1,
    wishlistName: 'Liste',
    removedAt: DateTime.utc(2026, 10, 29),
  );
}

void main() {
  // A Friday, local time.
  final now = DateTime(2026, 10, 30, 10);
  final friend = fakeFriendAppUser1;
  final friendId = friend.user.id;

  group('friendBirthdayCards', () {
    List<HomeCardCandidate> build(
      DateTime at,
      Birthday? birthday, {
      HomeCardDefinition? today,
      HomeCardDefinition? soon,
    }) {
      return friendBirthdayCards(
        friends: [friend],
        birthdays: {if (birthday != null) friendId: birthday},
        today: today ?? friendBirthdayToday,
        soon: soon ?? friendBirthdaySoon,
        now: at,
      );
    }

    Birthday inDays(int days) {
      final date = DateTime(now.year, now.month, now.day + days);
      return Birthday(month: date.month, day: date.day);
    }

    test('30 days ahead gives a light card', () {
      final cards = build(now, inDays(30));

      expect(cards, hasLength(1));
      expect(cards.single.type, 'friend_birthday');
      expect(cards.single.tone, HomeCardTone.light);
      expect(cards.single.dismissable, isTrue);
      expect(cards.single.eventAt, DateTime(2026, 11, 29));
      expect(cards.single.stateKey, 'friend_birthday:$friendId@2026');
      final content = cards.single.content as FriendBirthdaySoon;
      expect(content.days, 30);
      expect(content.friend, friend);
    });

    test('7 days ahead gives a highlighted card', () {
      final cards = build(now, inDays(7));

      expect(cards.single.type, 'friend_birthday');
      expect(cards.single.tone, HomeCardTone.highlighted);
    });

    test('31 days ahead gives nothing', () {
      expect(build(now, inDays(31)), isEmpty);
    });

    test('the day itself gives the highlighted "today" card', () {
      final cards = build(now, inDays(0));

      expect(cards.single.type, 'friend_birthday_today');
      expect(cards.single.tone, HomeCardTone.highlighted);
      expect(cards.single.stateKey, 'friend_birthday_today:$friendId@2026');
      expect(cards.single.content, isA<FriendBirthdayToday>());
    });

    test('a friend without a visible birthday gives nothing', () {
      expect(build(now, null), isEmpty);
    });

    test('a friend born on January 3 seen on December 20 has the key of 2027',
        () {
      final cards = build(
        DateTime(2026, 12, 20, 9),
        const Birthday(month: 1, day: 3),
      );

      expect(cards.single.stateKey, 'friend_birthday:$friendId@2027');
      expect(cards.single.eventAt, DateTime(2027, 1, 3));
    });

    test('a disabled type gives no card', () {
      final birthday = inDays(0);
      expect(
        friendBirthdayCards(
          friends: [friend],
          birthdays: {friendId: birthday},
          today: null,
          soon: friendBirthdaySoon,
          now: now,
        ),
        isEmpty,
      );
      expect(
        friendBirthdayCards(
          friends: [friend],
          birthdays: {friendId: inDays(10)},
          today: friendBirthdayToday,
          soon: null,
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('afterPartyCards', () {
    final holiday = wishlist(9, 'Vacances');

    List<HomeCardCandidate> build(
      DateTime at, {
      Birthday? mine,
      List<Wishlist>? wishlists,
      HomeCardDefinition? definition,
    }) {
      return afterPartyCards(
        myBirthday: mine,
        wishlists: wishlists ?? [holiday, wishlist(8, 'Maison')],
        userId: fakeCurrentUserId,
        definition: definition ?? afterPartyDef,
        christmas: christmasDef,
        now: at,
      );
    }

    test('the day after my birthday gives a card', () {
      final cards = build(now, mine: const Birthday(month: 10, day: 29));

      expect(cards.single.type, 'after_party');
      expect(cards.single.stateKey, 'after_party:birthday@2026');
      final content = cards.single.content as AfterParty;
      expect(content.occasion, AfterPartyOccasion.birthday);
      expect(content.daysAgo, 1);
      expect(content.wishlist, isNull);
    });

    test('without any wishlist there is no card, whatever the occasion', () {
      expect(
        build(
          now,
          mine: const Birthday(month: 10, day: 29),
          wishlists: const [],
        ),
        isEmpty,
      );
      expect(
        build(DateTime(2026, 12, 27, 9), wishlists: const []),
        isEmpty,
      );
    });

    test('closed or foreign wishlists do not count', () {
      final closed = wishlist(1, 'Noël 2026', isClosed: true);
      final foreign = wishlist(2, 'Noël 2026', owner: 'other');
      expect(
        build(DateTime(2026, 12, 27, 9), wishlists: [closed, foreign]),
        isEmpty,
      );
    });

    test('only my open wishlists count for the birthday one', () {
      final open = wishlist(1, 'Vacances');
      final cards = build(
        now,
        mine: const Birthday(month: 10, day: 29),
        wishlists: [
          open,
          wishlist(2, 'Ancienne', isClosed: true),
          wishlist(3, 'Autre', owner: 'other'),
        ],
      );

      expect((cards.single.content as AfterParty).wishlist, open);
    });

    test('the birthday itself gives nothing', () {
      expect(build(now, mine: const Birthday(month: 10, day: 30)), isEmpty);
    });

    test('8 days after with days_after = 7 gives nothing', () {
      expect(build(now, mine: const Birthday(month: 10, day: 22)), isEmpty);
    });

    test('a single wishlist is the one of the birthday', () {
      final single = wishlist(1, 'Vacances');
      final cards = build(
        now,
        mine: const Birthday(month: 10, day: 29),
        wishlists: [single],
      );

      expect((cards.single.content as AfterParty).wishlist, single);
    });

    test('several wishlists leave the birthday one unknown', () {
      final cards = build(
        now,
        mine: const Birthday(month: 10, day: 29),
        wishlists: [wishlist(1, 'Vacances'), wishlist(2, 'Maison')],
      );

      expect((cards.single.content as AfterParty).wishlist, isNull);
    });

    test('a birthday in December still counts in January, with its year', () {
      final cards = build(
        DateTime(2027, 1, 2, 9),
        mine: const Birthday(month: 12, day: 30),
      );

      expect(cards.single.stateKey, 'after_party:birthday@2026');
    });

    test('December 27 gives the Christmas card with the Christmas wishlist',
        () {
      final christmas = wishlist(2, 'Noël 2026');
      final cards = build(
        DateTime(2026, 12, 27, 9),
        wishlists: [wishlist(1, 'Vacances'), christmas],
      );

      expect(cards.single.stateKey, 'after_party:christmas@2026');
      final content = cards.single.content as AfterParty;
      expect(content.occasion, AfterPartyOccasion.christmas);
      expect(content.daysAgo, 2);
      expect(content.wishlist, christmas);
    });

    test('two wishlists without a Christmas name leave the list null', () {
      final cards = build(
        DateTime(2026, 12, 27, 9),
        wishlists: [wishlist(1, 'Vacances'), wishlist(2, 'Maison')],
      );

      expect((cards.single.content as AfterParty).wishlist, isNull);
    });

    test('Christmas day itself gives nothing', () {
      expect(build(DateTime(2026, 12, 25, 9)), isEmpty);
    });

    test('February 29 is celebrated on February 28 in a common year', () {
      final cards = build(
        DateTime(2027, 3, 1, 9),
        mine: const Birthday(month: 2, day: 29),
      );

      expect((cards.single.content as AfterParty).daysAgo, 1);
      expect(cards.single.stateKey, 'after_party:birthday@2027');
      expect(
        build(
          DateTime(2027, 2, 28, 9),
          mine: const Birthday(month: 2, day: 29),
        ),
        isEmpty,
      );
    });

    test('February 29 is celebrated on February 29 in a leap year', () {
      final cards = build(
        DateTime(2028, 3, 1, 9),
        mine: const Birthday(month: 2, day: 29),
      );

      expect((cards.single.content as AfterParty).daysAgo, 1);
      expect(cards.single.stateKey, 'after_party:birthday@2028');
      expect(
        build(
          DateTime(2028, 2, 29, 9),
          mine: const Birthday(month: 2, day: 29),
        ),
        isEmpty,
      );
    });

    test('a disabled type gives no card', () {
      final cards = afterPartyCards(
        myBirthday: const Birthday(month: 10, day: 29),
        wishlists: const [],
        userId: fakeCurrentUserId,
        definition: null,
        christmas: christmasDef,
        now: now,
      );
      expect(cards, isEmpty);
    });
  });

  group('bookedReminderCards', () {
    List<HomeCardCandidate> build(
      DateTime at,
      List<BookedWishWithDetails> bookings,
      Map<String, Birthday> birthdays,
    ) {
      return bookedReminderCards(
        bookings: bookings,
        birthdays: birthdays,
        definition: bookedReminderDef,
        now: at,
      );
    }

    test('an owner born in 10 days gives a card', () {
      final date = DateTime(2026, 11, 9);
      final cards = build(
        now,
        [fakeBookedWish1],
        {fakeBookedWish1.ownerId: Birthday(month: date.month, day: date.day)},
      );

      expect(cards.single.type, 'booked_reminder');
      expect(
        cards.single.stateKey,
        'booked_reminder:${fakeBookedWish1.wish.id}-birthday@2026',
      );
      final content = cards.single.content as BookedReminder;
      expect(content.days, 10);
      expect(content.occasion, ReminderOccasion.ownerBirthday);
      expect(content.booking, fakeBookedWish1);
      expect(cards.single.eventAt, date);
    });

    test('an owner born in 20 days with days_before = 14 gives nothing', () {
      final date = DateTime(2026, 11, 19);
      expect(
        build(
          now,
          [fakeBookedWish1],
          {fakeBookedWish1.ownerId: Birthday(month: date.month, day: date.day)},
        ),
        isEmpty,
      );
    });

    test('a given wish gives nothing', () {
      final date = DateTime(2026, 11, 9);
      expect(fakeBookedWishGiven.isGiven, isTrue);
      expect(
        build(
          now,
          [fakeBookedWishGiven],
          {
            fakeBookedWishGiven.ownerId:
                Birthday(month: date.month, day: date.day),
          },
        ),
        isEmpty,
      );
    });

    test('on December 15 without a close birthday the occasion is Christmas',
        () {
      final cards = build(DateTime(2026, 12, 15, 9), [fakeBookedWish1], {});

      final content = cards.single.content as BookedReminder;
      expect(content.occasion, ReminderOccasion.christmas);
      expect(content.days, 10);
      expect(
        cards.single.stateKey,
        'booked_reminder:${fakeBookedWish1.wish.id}-christmas@2026',
      );
    });

    test('the closest occasion wins', () {
      final cards = build(
        DateTime(2026, 12, 15, 9),
        [fakeBookedWish1],
        {fakeBookedWish1.ownerId: const Birthday(month: 12, day: 20)},
      );

      final content = cards.single.content as BookedReminder;
      expect(content.occasion, ReminderOccasion.ownerBirthday);
      expect(content.days, 5);
    });

    test('the birthday wins a tie with Christmas', () {
      final cards = build(
        DateTime(2026, 12, 20, 9),
        [fakeBookedWish1],
        {fakeBookedWish1.ownerId: const Birthday(month: 12, day: 25)},
      );

      final content = cards.single.content as BookedReminder;
      expect(content.occasion, ReminderOccasion.ownerBirthday);
      expect(content.days, 5);
    });

    test('an owner born on January 3 seen on December 26 has the key of 2027',
        () {
      final cards = build(
        DateTime(2026, 12, 26, 9),
        [fakeBookedWish1],
        {fakeBookedWish1.ownerId: const Birthday(month: 1, day: 3)},
      );

      expect(
        cards.single.stateKey,
        'booked_reminder:${fakeBookedWish1.wish.id}-birthday@2027',
      );
      expect(cards.single.eventAt, DateTime(2027, 1, 3));
    });

    test('hiding the birthday reminder does not hide the Christmas one', () {
      final wishId = fakeBookedWish1.wish.id;
      final owner = {
        fakeBookedWish1.ownerId: const Birthday(month: 3, day: 10),
      };
      final march = build(DateTime(2026, 3, 1, 9), [fakeBookedWish1], owner);
      final december = build(DateTime(2026, 12, 20, 9), [fakeBookedWish1], {});

      expect(march.single.stateKey, 'booked_reminder:$wishId-birthday@2026');
      expect(
        december.single.stateKey,
        'booked_reminder:$wishId-christmas@2026',
      );
      final hiddenMarch = {
        march.single.stateKey: CardState(
          cardKey: march.single.stateKey,
          shownCount: 1,
          dismissedAt: DateTime.utc(2026, 3),
        ),
      };
      final shown = selectHomeCards(
        candidates: december,
        definitions: {'booked_reminder': bookedReminderDef},
        states: hiddenMarch,
        maxCards: 3,
        now: DateTime(2026, 12, 20, 9),
      );
      expect(shown, hasLength(1));
    });

    test('counts whole days across a daylight saving change', () {
      // days_before is wide enough to reach Christmas from far away. Run the
      // file under TZ=Europe/Paris (change on March 29) and
      // TZ=America/Santiago (change on September 6) to exercise it.
      for (final start in [
        DateTime(2026, 3, 20, 12),
        DateTime(2026, 8, 31, 12),
      ]) {
        final expected = DateTime.utc(2026, 12, 25)
            .difference(DateTime.utc(start.year, start.month, start.day))
            .inDays;
        final cards = bookedReminderCards(
          bookings: [fakeBookedWish1],
          birthdays: const {},
          definition: def('booked_reminder', params: {'days_before': 400}),
          now: start,
        );

        expect((cards.single.content as BookedReminder).days, expected);
      }
    });

    test('a disabled type gives no card', () {
      expect(
        bookedReminderCards(
          bookings: [fakeBookedWish1],
          birthdays: const {},
          definition: null,
          now: DateTime(2026, 12, 15),
        ),
        isEmpty,
      );
    });
  });

  group('bookedWishRemovedCards', () {
    test('gives one card per alert, keyed by the alert id', () {
      final cards = bookedWishRemovedCards(
        removals: [removal(1), removal(2, ownerPseudo: '')],
        definition: removedDef,
        withOpenList: {2},
      );

      expect(cards.map((c) => c.stateKey), [
        'booked_wish_removed:1',
        'booked_wish_removed:2',
      ]);
      expect(cards.first.type, 'booked_wish_removed');
      expect(
        (cards.first.content as BookedWishRemoved).removal.ownerPseudo,
        'Alice',
      );
      expect(cards.first.eventAt, DateTime.utc(2026, 10, 29));
      expect((cards.first.content as BookedWishRemoved).canOpenList, isFalse);
      expect((cards.last.content as BookedWishRemoved).canOpenList, isTrue);
    });

    test('a disabled type gives no card', () {
      expect(
        bookedWishRemovedCards(
          removals: [removal(1)],
          definition: null,
          withOpenList: {1},
        ),
        isEmpty,
      );
    });
  });

  group('removalsWithOpenList', () {
    final open = wishlist(1, 'Liste');

    // The public wishlists of the owner, [friend] or not.
    Set<int> build(List<Wishlist> lists, {bool friend = true}) {
      return removalsWithOpenList(
        removals: [removal(1)],
        friendIds: friend ? const {'owner'} : const {},
        publicWishlists: {'owner': lists},
        now: now,
      );
    }

    test('a friend with an open wishlist keeps the button', () {
      expect(build([open]), {1});
    });

    test('an end date today or later is still open', () {
      expect(build([open.copyWith(endDate: DateTime(2026, 10, 30))]), {1});
    });

    test('someone who is no longer a friend loses the button', () {
      expect(build([open], friend: false), isEmpty);
    });

    test('a closed wishlist loses the button', () {
      expect(build([open.copyWith(isClosed: true)]), isEmpty);
    });

    test('an end date in the past loses the button', () {
      expect(build([open.copyWith(endDate: DateTime(2026, 10, 29))]), isEmpty);
    });

    test('a wishlist no longer visible (archived, private) loses it', () {
      expect(build(const []), isEmpty);
      expect(
        removalsWithOpenList(
          removals: [removal(1)],
          friendIds: const {'owner'},
          publicWishlists: const {},
          now: now,
        ),
        isEmpty,
      );
    });

    test('another open wishlist is not the one of the wish', () {
      expect(build([wishlist(2, 'Autre')]), isEmpty);
    });
  });

  group('friendAcceptedCards', () {
    List<HomeCardCandidate> build(Duration ago) {
      return friendAcceptedCards(
        accepted: [(friend: friend, acceptedAt: now.subtract(ago))],
        definition: acceptedDef,
        now: now,
      );
    }

    test('accepted 2 days ago gives a card', () {
      final cards = build(const Duration(days: 2));

      expect(cards.single.type, 'friend_accepted');
      expect(cards.single.stateKey, 'friend_accepted:$friendId');
      final content = cards.single.content as FriendAccepted;
      expect(content.friend, friend);
    });

    test('accepted 8 days ago with days = 7 gives nothing', () {
      expect(build(const Duration(days: 8)), isEmpty);
    });

    test('a disabled type gives no card', () {
      expect(
        friendAcceptedCards(
          accepted: [(friend: friend, acceptedAt: now)],
          definition: null,
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('christmasCards', () {
    List<HomeCardCandidate> build(
      DateTime at, [
      List<Wishlist> wishlists = const [],
    ]) {
      return christmasCards(
        wishlists: wishlists,
        userId: fakeCurrentUserId,
        definition: christmasDef,
        now: at,
      );
    }

    test('November 26 (29 days ahead) gives a light card', () {
      final cards = build(DateTime(2026, 11, 26, 9));

      expect(cards.single.type, 'christmas');
      expect(cards.single.tone, HomeCardTone.light);
      expect(cards.single.stateKey, 'christmas@2026');
      expect(cards.single.eventAt, DateTime(2026, 12, 25));
      expect((cards.single.content as Christmas).days, 29);
    });

    test('December 20 gives a highlighted card', () {
      expect(
        build(DateTime(2026, 12, 20, 9)).single.tone,
        HomeCardTone.highlighted,
      );
    });

    test('Christmas day gives a card when a Christmas wishlist is found', () {
      final christmas = wishlist(2, 'Noël 2026');
      final cards = build(DateTime(2026, 12, 25, 9), [christmas]);

      final content = cards.single.content as Christmas;
      expect(content.days, 0);
      expect(content.wishlist, christmas);
    });

    test(
        'Christmas day without a Christmas list but an open one still gives it',
        () {
      final cards = build(DateTime(2026, 12, 25, 9), [wishlist(1, 'Vacances')]);

      final content = cards.single.content as Christmas;
      expect(content.days, 0);
      expect(content.wishlist, isNull);
    });

    test('Christmas day without an open own wishlist gives nothing', () {
      final day = DateTime(2026, 12, 25, 9);
      expect(build(day), isEmpty);
      expect(
        build(day, [wishlist(1, 'Vacances', isClosed: true)]),
        isEmpty,
      );
      expect(
        build(day, [wishlist(1, 'Vacances', owner: 'other')]),
        isEmpty,
      );
    });

    test('December 24 without a Christmas wishlist still gives the card', () {
      final content =
          build(DateTime(2026, 12, 24, 9)).single.content as Christmas;

      expect(content.days, 1);
      expect(content.wishlist, isNull);
    });

    test('December 26 gives nothing', () {
      expect(build(DateTime(2026, 12, 26, 9)), isEmpty);
    });

    test('too early gives nothing', () {
      expect(build(DateTime(2026, 11, 20, 9)), isEmpty);
    });

    test('the Christmas wishlist is found by its name, else null', () {
      final christmas = wishlist(2, 'Noël 2026');
      final found = build(
        DateTime(2026, 12, 1, 9),
        [wishlist(1, 'Vacances'), christmas],
      );
      final missing =
          build(DateTime(2026, 12, 1, 9), [wishlist(1, 'Vacances')]);

      expect((found.single.content as Christmas).wishlist, christmas);
      expect((missing.single.content as Christmas).wishlist, isNull);
    });

    test('a Christmas wishlist of another user is ignored', () {
      final cards = christmasCards(
        wishlists: [wishlist(2, 'Noël 2026')],
        userId: 'someone-else',
        definition: christmasDef,
        now: DateTime(2026, 12, 1, 9),
      );

      expect((cards.single.content as Christmas).wishlist, isNull);
    });

    test('a disabled type gives no card', () {
      expect(
        christmasCards(
          wishlists: const [],
          userId: fakeCurrentUserId,
          definition: null,
          now: DateTime(2026, 12),
        ),
        isEmpty,
      );
    });
  });

  group('onboardingCards', () {
    List<HomeCardCandidate> build({
      int wishlistCount = 1,
      int friendCount = 1,
      bool hasBirthday = false,
      bool hasAvatar = false,
      Map<String, CardState> states = const {},
    }) {
      return onboardingCards(
        wishlistCount: wishlistCount,
        friendCount: friendCount,
        hasBirthday: hasBirthday,
        hasAvatar: hasAvatar,
        states: states,
        definition: onboardingDef,
        now: now,
      );
    }

    CardState state(
      String key, {
      DateTime? lastShownAt,
      DateTime? dismissedAt,
    }) {
      return CardState(
        cardKey: key,
        shownCount: 1,
        lastShownAt: lastShownAt,
        dismissedAt: dismissedAt,
      );
    }

    OnboardingStep step(List<HomeCardCandidate> cards) =>
        (cards.single.content as Onboarding).step;

    test('no wishlist gives step 1, which cannot be dismissed', () {
      final cards = build(wishlistCount: 0);

      expect(step(cards), OnboardingStep.firstWishlist);
      expect(cards.single.type, 'onboarding');
      expect(cards.single.dismissable, isFalse);
      expect(cards.single.stateKey, 'onboarding:firstWishlist');
    });

    test('a wishlist and no friend gives step 2, not dismissable', () {
      final cards = build(friendCount: 0);

      expect(step(cards), OnboardingStep.firstFriend);
      expect(cards.single.dismissable, isFalse);
    });

    test('an old account with wishlists and friends still gets step 3', () {
      // No account-age gate: everyone missing a birthday sees it once.
      final cards = build(wishlistCount: 6, friendCount: 12);

      expect(step(cards), OnboardingStep.birthday);
    });

    test('a wishlist, a friend and no birthday gives step 3', () {
      final cards = build();

      expect(step(cards), OnboardingStep.birthday);
      expect(cards.single.dismissable, isTrue);
      expect(cards.single.stateKey, 'onboarding:birthday');
    });

    test('a dismissed birthday step leaves step 4 when there is no photo', () {
      final cards = build(
        states: {
          'onboarding:birthday': state(
            'onboarding:birthday',
            dismissedAt: now,
          ),
        },
      );

      expect(step(cards), OnboardingStep.photo);
      expect(cards.single.stateKey, 'onboarding:photo');
    });

    test('a birthday set leaves step 4', () {
      expect(step(build(hasBirthday: true)), OnboardingStep.photo);
    });

    test('the optional steps end 48 hours after the window opened', () {
      final cards = build(
        states: {
          'onboarding:optional_window': state(
            'onboarding:optional_window',
            lastShownAt: now.subtract(const Duration(hours: 49)),
          ),
        },
      );

      expect(cards, isEmpty);
    });

    test('the optional steps stay inside the window', () {
      final cards = build(
        states: {
          'onboarding:optional_window': state(
            'onboarding:optional_window',
            lastShownAt: now.subtract(const Duration(hours: 47)),
          ),
        },
      );

      expect(step(cards), OnboardingStep.birthday);
    });

    test('the window does not hide steps 1 and 2', () {
      final cards = build(
        wishlistCount: 0,
        states: {
          'onboarding:optional_window': state(
            'onboarding:optional_window',
            lastShownAt: now.subtract(const Duration(days: 10)),
          ),
        },
      );

      expect(step(cards), OnboardingStep.firstWishlist);
    });

    test('a dismissed photo step is not shown', () {
      final cards = build(
        hasBirthday: true,
        states: {
          'onboarding:photo': state('onboarding:photo', dismissedAt: now),
        },
      );

      expect(cards, isEmpty);
    });

    test('everything filled in gives nothing', () {
      expect(build(hasBirthday: true, hasAvatar: true), isEmpty);
    });

    test('a disabled type gives no card', () {
      expect(
        onboardingCards(
          wishlistCount: 0,
          friendCount: 0,
          hasBirthday: false,
          hasAvatar: false,
          states: const {},
          definition: null,
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('staleWishlistCards', () {
    List<HomeCardCandidate> build(
      List<Wishlist> wishlists,
      Map<int, DateTime> lastActivity, {
      HomeCardDefinition? definition,
    }) {
      return staleWishlistCards(
        wishlists: wishlists,
        lastActivity: lastActivity,
        definition: definition ?? staleDef,
        now: now,
      );
    }

    DateTime daysAgo(int days) =>
        DateTime(now.year, now.month, now.day - days, 15);

    test('a list idle for 95 days gives a card', () {
      final cards = build([wishlist(1, 'Anniversaire')], {1: daysAgo(95)});

      expect(cards.single.type, 'stale_wishlist');
      expect(cards.single.stateKey, 'stale_wishlist:1');
      expect(cards.single.tone, HomeCardTone.light);
      final content = cards.single.content as StaleWishlist;
      expect(content.wishlist.id, 1);
      expect(content.monthsIdle, 3);
    });

    test('90 days is enough, 85 is not', () {
      expect(build([wishlist(1, 'A')], {1: daysAgo(90)}), hasLength(1));
      expect(build([wishlist(1, 'A')], {1: daysAgo(85)}), isEmpty);
    });

    test('only the oldest of two idle lists gives a card', () {
      final cards = build(
        [wishlist(1, 'A'), wishlist(2, 'B'), wishlist(3, 'C')],
        {1: daysAgo(120), 2: daysAgo(400), 3: daysAgo(100)},
      );

      expect(cards.single.stateKey, 'stale_wishlist:2');
      expect((cards.single.content as StaleWishlist).monthsIdle, 13);
    });

    test('a list without a known activity is ignored', () {
      expect(build([wishlist(1, 'A')], {2: daysAgo(200)}), isEmpty);
    });

    test('a closed list is ignored', () {
      expect(
        build([wishlist(1, 'A', isClosed: true)], {1: daysAgo(200)}),
        isEmpty,
      );
    });

    test('a disabled type gives nothing', () {
      final cards = staleWishlistCards(
        wishlists: [wishlist(1, 'A')],
        lastActivity: {1: daysAgo(200)},
        definition: null,
        now: now,
      );

      expect(cards, isEmpty);
    });
  });

  group('yearRecapFacts', () {
    test('counts what was received and offered in the year only', () {
      final facts = yearRecapFacts(
        received: [
          received(1, completedAt: on(2026, 3, 1)),
          received(2, completedAt: on(2026, 12, 1)),
          received(3, completedAt: DateTime(2025, 12, 31)),
        ],
        bookings: [
          offered(10, receivedAt: on(2026, 5, 1)),
          offered(11, receivedAt: on(2025, 5, 1)),
          offered(12, receivedAt: null),
        ],
        year: 2026,
      );

      expect(facts.year, 2026);
      expect(facts.receivedCount, 2);
      expect(facts.offeredCount, 1);
    });

    test('the longest awaited is the earliest created wish of the year', () {
      final facts = yearRecapFacts(
        received: [
          received(
            1,
            completedAt: on(2026, 3, 1),
            createdAt: on(2024, 6, 1),
            name: 'Old',
          ),
          received(
            2,
            completedAt: on(2026, 4, 1),
            createdAt: on(2025, 1, 1),
          ),
          received(
            3,
            completedAt: on(2025, 4, 1),
            createdAt: on(2020, 1, 1),
            name: 'Last year',
          ),
        ],
        bookings: const [],
        year: 2026,
      );

      expect(facts.longestAwaited?.wish.name, 'Old');
    });

    test('there is no longest awaited without a received wish', () {
      final facts = yearRecapFacts(
        received: const [],
        bookings: [offered(10, receivedAt: on(2026, 5, 1))],
        year: 2026,
      );

      expect(facts.longestAwaited, isNull);
    });

    test('the most gifted friend is the one who got the most wishes', () {
      final facts = yearRecapFacts(
        received: const [],
        bookings: [
          offered(10, receivedAt: on(2026, 1, 1)),
          offered(
            11,
            receivedAt: on(2026, 2, 1),
            ownerId: fakeFriendUserId2,
            ownerPseudo: 'Bob',
          ),
          offered(
            12,
            receivedAt: on(2026, 3, 1),
            ownerId: fakeFriendUserId2,
            ownerPseudo: 'Bob',
          ),
        ],
        year: 2026,
      );

      expect(facts.mostGiftedFriendPseudo, 'Bob');
    });

    test('a tie, or nothing offered, gives no most gifted friend', () {
      final tie = yearRecapFacts(
        received: const [],
        bookings: [
          offered(10, receivedAt: on(2026, 1, 1)),
          offered(
            11,
            receivedAt: on(2026, 2, 1),
            ownerId: fakeFriendUserId2,
            ownerPseudo: 'Bob',
          ),
        ],
        year: 2026,
      );
      final none = yearRecapFacts(
        received: [received(1, completedAt: on(2026, 3, 1))],
        bookings: const [],
        year: 2026,
      );

      expect(tie.mostGiftedFriendPseudo, isNull);
      expect(none.mostGiftedFriendPseudo, isNull);
    });
  });

  group('yearRecapCards', () {
    final december = DateTime(2026, 12, 10, 9);
    const facts = YearRecapFacts(
      year: 2026,
      receivedCount: 3,
      offeredCount: 2,
    );

    test('a dark card on December 10 with received and offered wishes', () {
      final cards = yearRecapCards(
        facts: facts,
        definition: yearRecapDef,
        now: december,
      );

      expect(cards.single.type, 'year_recap');
      expect(cards.single.stateKey, 'year_recap@2026');
      expect(cards.single.tone, HomeCardTone.dark);
      expect((cards.single.content as YearRecap).facts, facts);
    });

    test('nothing in November', () {
      expect(
        yearRecapCards(
          facts: facts,
          definition: yearRecapDef,
          now: DateTime(2026, 11, 30, 23),
        ),
        isEmpty,
      );
    });

    test('the month comes from the definition', () {
      expect(
        yearRecapCards(
          facts: facts,
          definition: def('year_recap', params: {'month': 11}),
          now: DateTime(2026, 11, 30),
        ),
        hasLength(1),
      );
    });

    test('nothing without any activity in the year', () {
      expect(
        yearRecapCards(
          facts: const YearRecapFacts(
            year: 2026,
            receivedCount: 0,
            offeredCount: 0,
          ),
          definition: yearRecapDef,
          now: december,
        ),
        isEmpty,
      );
    });

    test('a disabled type gives nothing', () {
      expect(
        yearRecapCards(facts: facts, definition: null, now: december),
        isEmpty,
      );
    });
  });

  group('hideUntil', () {
    final definitions = {
      'friend_birthday': friendBirthdaySoon,
      'christmas': christmasDef,
      'booked_reminder': bookedReminderDef,
      'stale_wishlist': staleDef,
    };

    test('a friend birthday at 20 days comes back at 7 days', () {
      final date = DateTime(now.year, now.month, now.day + 20);
      final cards = friendBirthdayCards(
        friends: [friend],
        birthdays: {friendId: Birthday(month: date.month, day: date.day)},
        today: friendBirthdayToday,
        soon: friendBirthdaySoon,
        now: now,
      );

      expect(
        hideUntil(cards.single, definitions, now),
        DateTime(date.year, date.month, date.day - 7),
      );
    });

    test('Christmas at 20 days comes back at 7 days', () {
      final at = DateTime(2026, 12, 5, 9);
      final cards = christmasCards(
        wishlists: const [],
        userId: fakeCurrentUserId,
        definition: christmasDef,
        now: at,
      );

      expect(hideUntil(cards.single, definitions, at), DateTime(2026, 12, 18));
    });

    test('a stale wishlist comes back in 60 days', () {
      final cards = staleWishlistCards(
        wishlists: [wishlist(1, 'A')],
        lastActivity: {1: on(2026, 1, 1)},
        definition: staleDef,
        now: now,
      );

      expect(
        hideUntil(cards.single, definitions, now),
        DateTime(2026, 12, 29, 10),
      );
    });

    test('a booked reminder is hidden for good', () {
      final cards = bookedReminderCards(
        bookings: [fakeBookedWish1],
        birthdays: const {},
        definition: bookedReminderDef,
        now: DateTime(2026, 12, 15),
      );

      expect(hideUntil(cards.single, definitions, now), isNull);
    });
  });
}
