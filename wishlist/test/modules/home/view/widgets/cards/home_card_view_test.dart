import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/view/widgets/cards/home_card_view.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';

import '../../../../../fixtures/fake_data.dart';
import '../../../../../fixtures/fake_providers.dart';
import '../../../../../pump_app.dart';

HomeCardCandidate card(
  HomeCardContent content, {
  HomeCardTone tone = HomeCardTone.light,
  bool dismissable = true,
}) {
  return HomeCardCandidate(
    type: 'test',
    stateKey: 'test',
    content: content,
    tone: tone,
    dismissable: dismissable,
  );
}

BookedWishRemoval removal({String pseudo = 'Alice'}) {
  return BookedWishRemoval(
    id: 7,
    ownerId: fakeFriendUserId1,
    ownerPseudo: pseudo,
    wishId: 99,
    wishName: 'Casque',
    quantity: 1,
    wishlistName: 'Anniversaire',
    removedAt: fakeNow,
  );
}

void main() {
  var hidden = 0;
  setUp(() => hidden = 0);

  Future<void> pumpCard(
    WidgetTester tester,
    HomeCardCandidate candidate, {
    WindowConfigData? windowConfig,
  }) async {
    await tester.pumpRouterApp(
      '/card',
      windowConfig: windowConfig,
      routes: [
        GoRoute(
          path: '/card',
          builder: (context, state) => Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: HomeCardView(card: candidate, onHide: () => hidden++),
              ),
            ),
          ),
        ),
        // Any other route shows where it led
        GoRoute(
          path: '/:rest(.*)',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                Text('at ${state.uri.path}'),
                Text('query ${state.uri.query}'),
              ],
            ),
          ),
        ),
      ],
      overrides: [
        ...homeScreenOverrides(now: fakeNow),
        watchWishsFromWishlistProvider.overrideWith(
          (ref, id) => Stream.value(fakeWishes.toIList()),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndExpectPath(
    WidgetTester tester,
    String label,
    String path,
  ) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(find.text('at $path'), findsOneWidget);
  }

  group('contents', () {
    testWidgets('a friend birthday today opens the list of the friend',
        (tester) async {
      await pumpCard(
        tester,
        card(
          FriendBirthdayToday(fakeFriendAppUser1),
          tone: HomeCardTone.highlighted,
        ),
      );

      expect(find.text("C'est aujourd'hui !"), findsOneWidget);
      expect(find.text('Joyeux anniversaire à Alice'), findsOneWidget);
      await tapAndExpectPath(
        tester,
        'Voir sa liste',
        '/friend/$fakeFriendUserId1',
      );
    });

    testWidgets('a friend birthday soon shows the date and the countdown',
        (tester) async {
      await pumpCard(
        tester,
        card(
          FriendBirthdaySoon(
            fakeFriendAppUser1,
            const Birthday(month: 11, day: 4),
            6,
          ),
        ),
      );

      expect(find.text('4 novembre · dans 6 jours'), findsOneWidget);
      expect(find.text('Anniversaire de Alice'), findsOneWidget);
      await tapAndExpectPath(
        tester,
        'Voir ses wishlists',
        '/friend/$fakeFriendUserId1',
      );
    });

    testWidgets('after the birthday, opens the wishlist', (tester) async {
      await pumpCard(
        tester,
        card(AfterParty(AfterPartyOccasion.birthday, 3, fakeWishlist1)),
      );

      expect(
        find.text("Ton anniversaire, c'était il y a 3 jours"),
        findsOneWidget,
      );
      expect(find.text('Tu as été gâté ?'), findsOneWidget);
      expect(
        find.text(
          'Ouvre la bonne liste ci-dessous pour cocher ce que tu as reçu.',
        ),
        findsNothing,
      );
      await tapAndExpectPath(tester, "Cocher ce que j'ai reçu", '/wishlist/1');
    });

    testWidgets('after Christmas yesterday, singular', (tester) async {
      await pumpCard(
        tester,
        card(AfterParty(AfterPartyOccasion.christmas, 1, fakeWishlist2)),
      );

      expect(find.text("Noël, c'était hier"), findsOneWidget);
      expect(find.text('Le Père Noël est passé ?'), findsOneWidget);
      expect(
        find.text(
          'Ouvre la bonne liste ci-dessous pour cocher ce que tu as reçu.',
        ),
        findsNothing,
      );
    });

    testWidgets('after the party without a wishlist has no button',
        (tester) async {
      await pumpCard(
        tester,
        card(const AfterParty(AfterPartyOccasion.birthday, 2, null)),
      );

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Tu as été gâté ?'), findsOneWidget);
      expect(
        find.text(
          'Ouvre la bonne liste ci-dessous pour cocher ce que tu as reçu.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('after Christmas without a wishlist points to the grid',
        (tester) async {
      await pumpCard(
        tester,
        card(const AfterParty(AfterPartyOccasion.christmas, 2, null)),
      );

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Le Père Noël est passé ?'), findsOneWidget);
      expect(
        find.text(
          'Ouvre la bonne liste ci-dessous pour cocher ce que tu as reçu.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a booked reminder opens the wish', (tester) async {
      await pumpCard(
        tester,
        card(
          BookedReminder(
            fakeBookedWish1,
            ReminderOccasion.ownerBirthday,
            5,
          ),
        ),
      );

      expect(
        find.text('Rappel · Alice fête son anniversaire dans 5 jours'),
        findsOneWidget,
      );
      expect(find.text('Tu as réservé ${fakeWish1.name}'), findsOneWidget);
      await tapAndExpectPath(
        tester,
        'Voir le wish',
        '/wishlist/${fakeWish1.wishlistId}/wish/${fakeWish1.id}',
      );
    });

    testWidgets('a booked reminder opens the wish as the Booked tab does',
        (tester) async {
      await pumpCard(
        tester,
        card(
          BookedReminder(
            fakeBookedWish1,
            ReminderOccasion.ownerBirthday,
            5,
          ),
        ),
      );

      await tester.tap(find.text('Voir le wish'));
      await tester.pumpAndSettle();

      expect(find.textContaining('quantity-display=my-booked'), findsOneWidget);
    });

    testWidgets('a booked reminder on the day does not say 0 days',
        (tester) async {
      await pumpCard(
        tester,
        card(
          BookedReminder(
            fakeBookedWish1,
            ReminderOccasion.ownerBirthday,
            0,
          ),
        ),
      );

      expect(
        find.text("Rappel · Alice fête son anniversaire aujourd'hui"),
        findsOneWidget,
      );
      expect(find.textContaining('0 jours'), findsNothing);
    });

    testWidgets('a Christmas booked reminder', (tester) async {
      await pumpCard(
        tester,
        card(BookedReminder(fakeBookedWish1, ReminderOccasion.christmas, 0)),
      );

      expect(find.text("Rappel · c'est Noël aujourd'hui"), findsOneWidget);
    });

    testWidgets('a removed wish names its owner and opens their list',
        (tester) async {
      await pumpCard(
        tester,
        card(BookedWishRemoved(removal(), canOpenList: true)),
      );

      expect(find.text('Changement chez Alice'), findsOneWidget);
      expect(
        find.text('Alice a retiré Casque que tu avais réservé'),
        findsOneWidget,
      );
      expect(find.text('!'), findsOneWidget);
      await tapAndExpectPath(
        tester,
        'Voir sa liste',
        '/friend/$fakeFriendUserId1',
      );
    });

    testWidgets('a removed wish without an openable list only informs',
        (tester) async {
      await pumpCard(
        tester,
        card(BookedWishRemoved(removal(), canOpenList: false)),
      );

      expect(
        find.text('Alice a retiré Casque que tu avais réservé'),
        findsOneWidget,
      );
      expect(find.text('Voir sa liste'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(
        find.text("Si tu l'as déjà acheté, tu peux toujours l'offrir."),
        findsOneWidget,
      );
    });

    testWidgets('a removed wish of an owner without pseudo is neutral',
        (tester) async {
      await pumpCard(
        tester,
        card(BookedWishRemoved(removal(pseudo: ''), canOpenList: true)),
      );

      expect(
        find.text('Un wish que tu avais réservé a été retiré'),
        findsOneWidget,
      );
      expect(find.textContaining('  '), findsNothing);
    });

    testWidgets('an accepted request shows when and opens the wishlists',
        (tester) async {
      await pumpCard(
        tester,
        card(FriendAccepted(fakeFriendAppUser1, fakeNow)),
      );

      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text('Alice a accepté ta demande'), findsOneWidget);
      await tapAndExpectPath(
        tester,
        'Voir ses wishlists',
        '/friend/$fakeFriendUserId1',
      );
    });

    testWidgets('Christmas with a list shows its name and wish count',
        (tester) async {
      await pumpCard(tester, card(Christmas(12, fakeWishlist2)));

      expect(find.text('Noël dans 12 jours'), findsOneWidget);
      expect(find.text('Ta liste « Noël » a 2 wishs'), findsOneWidget);
      await tapAndExpectPath(tester, 'Compléter', '/wishlist/2');
    });

    testWidgets('Christmas tomorrow is still the countdown, not the day',
        (tester) async {
      await pumpCard(tester, card(Christmas(1, fakeWishlist2)));

      expect(find.text('Ta liste « Noël » a 2 wishs'), findsOneWidget);
      expect(find.text("C'est Noël !"), findsNothing);
      await tapAndExpectPath(tester, 'Compléter', '/wishlist/2');
    });

    testWidgets('Christmas day says it is Christmas', (tester) async {
      await pumpCard(tester, card(Christmas(0, fakeWishlist2)));

      expect(find.text("C'est Noël !"), findsOneWidget);
      expect(find.textContaining('dans 0'), findsNothing);
      expect(find.text('Joyeux Noël !'), findsOneWidget);
      expect(find.text('Ta liste « Noël »'), findsOneWidget);
      await tapAndExpectPath(tester, 'Voir ma liste', '/wishlist/2');
    });

    testWidgets('Christmas without a list offers to create one',
        (tester) async {
      await pumpCard(tester, card(const Christmas(20, null)));

      expect(find.text('Noël approche'), findsOneWidget);
      await tester.tap(find.text('Créer ma liste de Noël'));
      await tester.pumpAndSettle();
      expect(find.text('Créer une wishlist'), findsOneWidget);
    });

    testWidgets('onboarding step 1 opens the create dialog', (tester) async {
      await pumpCard(
        tester,
        card(
          const Onboarding(OnboardingStep.firstWishlist),
          dismissable: false,
        ),
      );

      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(find.text('Crée ta première wishlist'), findsOneWidget);
      await tester.tap(find.text('Créer une wishlist').first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('onboarding step 2 opens the add friend sheet', (tester) async {
      await pumpCard(
        tester,
        card(
          const Onboarding(OnboardingStep.firstFriend),
          dismissable: false,
        ),
      );

      expect(find.text('Ajoute un ami'), findsOneWidget);
      await tester.tap(find.text('Ajouter un ami'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('onboarding step 3 opens the birthday screen', (tester) async {
      await pumpCard(tester, card(const Onboarding(OnboardingStep.birthday)));

      expect(find.text('Étape 3 sur 4'), findsOneWidget);
      await tapAndExpectPath(tester, 'Ajouter', '/profile/change-birthday');
    });

    testWidgets('onboarding step 4 opens the profile', (tester) async {
      await pumpCard(tester, card(const Onboarding(OnboardingStep.photo)));

      expect(find.text('Mets une photo'), findsOneWidget);
      await tapAndExpectPath(tester, 'Choisir une photo', '/profile');
    });
  });

  group('layout', () {
    testWidgets('a long overline uses the free width of the card',
        (tester) async {
      tester.view
        ..physicalSize = const Size(375 * 3, 800 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final booking = fakeBookedWish1.copyWith(
        ownerPseudo: 'Alexandrine-Joséphine',
      );
      await pumpCard(
        tester,
        card(BookedReminder(booking, ReminderOccasion.ownerBirthday, 5)),
      );

      final overline = find.textContaining('Rappel');
      // Half of the row would be about 150: it takes the room left by the
      // cross, up to the edge of the card
      expect(tester.getSize(overline).width, greaterThan(250));
    });

    testWidgets('the cross has a 48 px hit area', (tester) async {
      await pumpCard(tester, card(FriendBirthdayToday(fakeFriendAppUser1)));

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.widget<IconButton>(find.byType(IconButton)).iconSize, 18);
    });
  });

  group('cross', () {
    testWidgets('calls onHide', (tester) async {
      await pumpCard(tester, card(FriendBirthdayToday(fakeFriendAppUser1)));

      await tester.tap(find.byTooltip('Masquer'));

      expect(hidden, 1);
    });

    testWidgets('is absent when the card cannot be hidden', (tester) async {
      await pumpCard(
        tester,
        card(
          const Onboarding(OnboardingStep.firstWishlist),
          dismissable: false,
        ),
      );

      expect(find.byTooltip('Masquer'), findsNothing);
    });
  });

  group('golden', () {
    for (final tone in [HomeCardTone.light, HomeCardTone.highlighted]) {
      testAdaptiveWidgets('$HomeCardView golden test ${tone.name}',
          (tester, variant) async {
        await pumpCard(
          tester,
          card(BookedWishRemoved(removal(), canOpenList: true), tone: tone),
          windowConfig: variant,
        );

        await tester.expectGolden<HomeCardView>(variant, suffix: tone.name);
      });
    }
  });
}
