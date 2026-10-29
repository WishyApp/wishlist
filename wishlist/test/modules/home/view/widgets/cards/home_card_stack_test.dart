import 'dart:async';
import 'dart:math';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/modules/home/view/widgets/cards/home_card_stack.dart';
import 'package:wishlist/modules/home/view/widgets/cards/home_card_view.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository_provider.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

import '../../../../../fixtures/fake_data.dart';
import '../../../../../fixtures/fake_providers.dart';
import '../../../../../pump_app.dart';

class MockCardStateRepository extends Mock implements CardStateRepository {}

class MockBookedWishRemovalRepository extends Mock
    implements BookedWishRemovalRepository {}

const _firstTitle = 'Alice a accepté ta demande';

void main() {
  late MockCardStateRepository cardStates;
  late MockBookedWishRemovalRepository removals;

  // Three cards of the same friend, told apart by their keys: the first one
  // is the only one with its text.
  final cards = [
    HomeCardCandidate(
      type: 'friend_accepted',
      stateKey: 'friend_accepted:a',
      content: FriendAccepted(fakeFriendAppUser1, fakeNow),
    ),
    const HomeCardCandidate(
      type: 'onboarding',
      stateKey: 'onboarding:birthday',
      content: Onboarding(OnboardingStep.birthday),
    ),
    const HomeCardCandidate(
      type: 'onboarding',
      stateKey: 'onboarding:photo',
      content: Onboarding(OnboardingStep.photo),
    ),
  ];

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    cardStates = MockCardStateRepository();
    removals = MockBookedWishRemovalRepository();
    when(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    ).thenAnswer((_) async {});
    when(() => cardStates.recordShown(any())).thenAnswer((_) async {});
  });

  List<Override> overrides(Future<List<HomeCardCandidate>> Function() load) {
    return [
      ...homeScreenOverrides(now: fakeNow, overrideHomeCards: false),
      homeCardsProvider.overrideWith((ref) => load()),
      homeCardDefinitionsProvider.overrideWith(
        (ref) async => {
          'home_stack': const HomeCardDefinition(
            key: 'home_stack',
            kind: HomeCardKind.settings,
            priority: 0,
            params: {'later_days': 1},
          ),
        },
      ),
      cardStateRepositoryProvider.overrideWithValue(cardStates),
      bookedWishRemovalRepositoryProvider.overrideWithValue(removals),
    ];
  }

  Future<void> pump(
    WidgetTester tester,
    Future<List<HomeCardCandidate>> Function() load, {
    WindowConfigData? windowConfig,
  }) async {
    await tester.pumpApp(
      const Scaffold(
        body: SafeArea(child: SingleChildScrollView(child: HomeCardsSlot())),
      ),
      windowConfig: windowConfig,
      overrides: overrides(load),
    );
    await tester.pumpAndSettle();
  }

  /// Lets the card leave and the snack-bar come, without waiting for the
  /// snack-bar to end (pumpAndSettle would).
  Future<void> letItLeave(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Lets the snack-bar and the delay of the swipe end.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the first card and two edges behind it', (tester) async {
    await pump(tester, () async => cards);

    expect(find.text(_firstTitle), findsOneWidget);
    expect(find.text('Ajoute ton anniversaire'), findsNothing);
    expect(find.byType(HomeCardEdge), findsNWidgets(2));
  });

  testWidgets('one card behind it has one edge', (tester) async {
    await pump(tester, () async => cards.take(2).toList());

    expect(find.byType(HomeCardEdge), findsOneWidget);
  });

  testWidgets('a single card has no edge', (tester) async {
    await pump(tester, () async => cards.take(1).toList());

    expect(find.byType(HomeCardEdge), findsNothing);
  });

  testWidgets('shows nothing while loading and on error', (tester) async {
    await pump(tester, () => Completer<List<HomeCardCandidate>>().future);
    expect(find.byType(HomeCardView), findsNothing);

    await pump(tester, () async => throw Exception('offline'));
    expect(find.byType(HomeCardView), findsNothing);
  });

  testWidgets('keeps the cards while they reload', (tester) async {
    var loads = 0;
    final second = Completer<List<HomeCardCandidate>>();
    await pump(tester, () {
      loads++;
      return loads == 1 ? Future.value(cards) : second.future;
    });
    expect(find.text(_firstTitle), findsOneWidget);

    ProviderScope.containerOf(tester.element(find.byType(HomeCardsSlot)))
        .invalidate(homeCardsProvider);
    await tester.pump();
    await tester.pump();

    expect(loads, 2);
    expect(find.text(_firstTitle), findsOneWidget);
    second.complete(cards);
    await tester.pumpAndSettle();
    expect(find.text(_firstTitle), findsOneWidget);
  });

  testWidgets('swipe left hides the card, the next one comes on top',
      (tester) async {
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);

    expect(find.text(_firstTitle), findsNothing);
    expect(find.text('Ajoute ton anniversaire'), findsOneWidget);
    expect(find.text('Carte masquée'), findsOneWidget);
    expect(find.byType(HomeCardEdge), findsOneWidget);
    // Nothing is sent before the end of the snack-bar
    verifyNever(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    );

    await finish(tester);
    verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
    // The card does not come back while the pile reloads
    expect(find.text(_firstTitle), findsNothing);
  });

  testWidgets('the slot never collapses while the next card replaces the top',
      (tester) async {
    await pump(tester, () async => cards.take(2).toList());

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    var lowest = double.infinity;
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      lowest = min(lowest, tester.getSize(find.byType(HomeCardsSlot)).height);
    }
    await tester.pump(const Duration(milliseconds: 500));

    // The height ends at the one of the next card (no edge behind it), and
    // never went below it on the way
    final settled = tester.getSize(find.byType(HomeCardsSlot)).height;
    expect(find.text('Ajoute ton anniversaire'), findsOneWidget);
    expect(find.byType(HomeCardEdge), findsNothing);
    expect(settled, greaterThan(100));
    expect(lowest, greaterThanOrEqualTo(settled));
  });

  testWidgets('swipe right postpones the card', (tester) async {
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(500, 0));
    await letItLeave(tester);

    expect(find.text('Reportée à demain'), findsOneWidget);
    await finish(tester);
    verify(
      () => cardStates.dismiss(
        'friend_accepted:a',
        snoozeUntil: DateTime(fakeNow.year, fakeNow.month, fakeNow.day + 1),
      ),
    ).called(1);
  });

  testWidgets('shows what a swipe does under the card', (tester) async {
    await pump(tester, () async => cards);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(_firstTitle)),
    );
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(find.text('Plus tard'), findsOneWidget);
    await gesture.moveBy(const Offset(-300, 0));
    await tester.pump();
    expect(find.text('Masquer'), findsWidgets);
    await gesture.up();
    await finish(tester);
  });

  testWidgets('"Annuler" brings the first card back and sends nothing',
      (tester) async {
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);
    await tester.tap(find.text('Annuler'));
    await letItLeave(tester);

    expect(find.text(_firstTitle), findsOneWidget);
    await finish(tester);
    verifyNever(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    );
  });

  testWidgets('the cross hides the card like a swipe', (tester) async {
    await pump(tester, () async => cards);

    await tester.tap(find.byTooltip('Masquer'));
    await letItLeave(tester);

    expect(find.text('Carte masquée'), findsOneWidget);
    expect(find.text(_firstTitle), findsNothing);
    await finish(tester);
    verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
  });

  testWidgets('a card that cannot be hidden cannot be swiped', (tester) async {
    await pump(
      tester,
      () async => [
        const HomeCardCandidate(
          type: 'onboarding',
          stateKey: 'onboarding:firstWishlist',
          content: Onboarding(OnboardingStep.firstWishlist),
          dismissable: false,
        ),
      ],
    );

    expect(find.byType(Dismissible), findsNothing);
    await tester.drag(
      find.text('Crée ta première wishlist'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crée ta première wishlist'), findsOneWidget);
    expect(find.text('Carte masquée'), findsNothing);
  });

  testWidgets('the card is sent when the snack-bar closes, not on a timer',
      (tester) async {
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);
    // The snack-bar lasts 4 s, the fallback timer 5 s
    await tester.pump(const Duration(milliseconds: 3000));
    verifyNever(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    );
    await tester.pump(const Duration(milliseconds: 800));

    verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
    await finish(tester);
  });

  testWidgets('swiping the snack-bar away sends the card', (tester) async {
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);
    await tester.drag(find.text('Carte masquée'), const Offset(600, 0));
    await letItLeave(tester);

    verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
    await finish(tester);
  });

  testWidgets('leaving the screen closes the snack-bar: no Undo left',
      (tester) async {
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);
    expect(find.text('Annuler'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(find.text('Annuler'), findsNothing);
    verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
  });

  testWidgets('going to the background sends the card and closes the snack-bar',
      (tester) async {
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
    expect(find.text('Annuler'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await finish(tester);
  });

  group('cards closed for good', () {
    final removal = HomeCardCandidate(
      type: 'booked_wish_removed',
      stateKey: 'booked_wish_removed:7',
      content: BookedWishRemoved(
        BookedWishRemoval(
          id: 7,
          ownerId: fakeFriendUserId1,
          ownerPseudo: 'Alice',
          wishId: 9,
          wishName: 'Casque',
          quantity: 1,
          wishlistName: 'Liste',
          removedAt: fakeNow,
        ),
        canOpenList: true,
      ),
    );
    const photo = HomeCardCandidate(
      type: 'onboarding',
      stateKey: 'onboarding:photo',
      content: Onboarding(OnboardingStep.photo),
    );
    const birthday = HomeCardCandidate(
      type: 'onboarding',
      stateKey: 'onboarding:birthday',
      content: Onboarding(OnboardingStep.birthday),
    );

    for (final card in [removal, photo, birthday]) {
      testWidgets('${card.stateKey} cannot be postponed', (tester) async {
        await pump(tester, () async => [card]);

        await tester.drag(find.byType(HomeCardView), const Offset(500, 0));
        await letItLeave(tester);

        expect(find.byType(HomeCardView), findsOneWidget);
        expect(find.textContaining('Reportée'), findsNothing);

        await tester.drag(find.byType(HomeCardView), const Offset(-500, 0));
        await letItLeave(tester);
        expect(find.text('Carte masquée'), findsOneWidget);
        await finish(tester);
      });
    }

    testWidgets('a card that comes back can be postponed', (tester) async {
      await pump(tester, () async => cards);

      await tester.drag(find.text(_firstTitle), const Offset(500, 0));
      await letItLeave(tester);

      expect(find.text('Reportée à demain'), findsOneWidget);
      await finish(tester);
    });
  });

  group('accessibility', () {
    testWidgets('the top card offers Later and Hide as actions',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, () async => cards);

      final data = tester
          .getSemantics(
            find.descendant(
              of: find.byType(HomeCardStack),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Semantics &&
                    w.properties.customSemanticsActions != null,
              ),
            ),
          )
          .getSemanticsData();
      final labels = [
        for (final id in data.customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(labels, containsAll(['Plus tard', 'Masquer']));
      handle.dispose();
    });

    testWidgets('the Hide action of a card closed for good has no Later',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, () async => [cards[1]]);

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.customSemanticsActions != null,
        ),
      );
      final labels = [
        for (final action in semantics.properties.customSemanticsActions!.keys)
          action.label,
      ];
      expect(labels, ['Masquer']);
      handle.dispose();
    });

    testWidgets('with a screen reader the snack-bar stays and nothing is sent',
        (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
            child: const Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(child: HomeCardsSlot()),
              ),
            ),
          ),
        ),
        overrides: overrides(() async => cards),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
      await letItLeave(tester);
      await tester.pump(const Duration(minutes: 1));

      expect(find.text('Carte masquée'), findsOneWidget);
      verifyNever(
        () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
      );

      // Leaving still sends it
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
    });
  });

  testWidgets('records the top card once, then the next one', (tester) async {
    await pump(tester, () async => cards);

    verify(() => cardStates.recordShown('friend_accepted:a')).called(1);
    verifyNever(() => cardStates.recordShown('onboarding:birthday'));

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);

    verify(() => cardStates.recordShown('onboarding:birthday')).called(1);
    await finish(tester);
  });

  testWidgets('leaving the screen right after a swipe still sends it',
      (tester) async {
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);
    verifyNever(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
    await tester.pump(const Duration(seconds: 5));
  });

  group('swipe slot', () {
    testWidgets('the swiped card and its backgrounds are clipped to the slot',
        (tester) async {
      await pump(tester, () async => cards);

      final clip = find.ancestor(
        of: find.byType(Dismissible),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ClipRRect &&
              widget.borderRadius == BorderRadius.circular(22),
        ),
      );
      expect(clip, findsOneWidget);
      // The card is flat inside the slot: its own corners would show the
      // background as a block next to it
      expect(tester.widget<HomeCardView>(find.byType(HomeCardView)).flat, true);
    });

    testWidgets('the slot draws the outline over the card and the background',
        (tester) async {
      await pump(tester, () async => cards);

      final outline = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(ClipRRect),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(outline.position, DecorationPosition.foreground);
      final decoration = outline.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(22));
      expect(decoration.border, isNotNull);
    });

    testWidgets('the edges stay outside of the clip', (tester) async {
      await pump(tester, () async => cards);

      expect(
        find.descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(HomeCardEdge),
        ),
        findsNothing,
      );
    });

    testWidgets('a card that cannot be hidden keeps its own shape',
        (tester) async {
      await pump(
        tester,
        () async => [
          const HomeCardCandidate(
            type: 'onboarding',
            stateKey: 'onboarding:firstWishlist',
            content: Onboarding(OnboardingStep.firstWishlist),
            dismissable: false,
          ),
        ],
      );

      expect(
        tester.widget<HomeCardView>(find.byType(HomeCardView)).flat,
        false,
      );
    });

    testAdaptiveWidgets('$HomeCardStack mid-swipe golden test',
        (tester, variant) async {
      await pump(tester, () async => cards, windowConfig: variant);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text(_firstTitle)),
      );
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();

      await tester.expectGolden<HomeCardStack>(variant, suffix: 'mid_swipe');
      await gesture.up();
      await finish(tester);
    });
  });
}
