import 'dart:async';
import 'dart:math';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/foundation.dart';
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
import '../../../../../fixtures/lifecycle.dart';
import '../../../../../pump_app.dart';

class MockCardStateRepository extends Mock implements CardStateRepository {}

class MockBookedWishRemovalRepository extends Mock
    implements BookedWishRemovalRepository {}

const _firstTitle = 'Alice a accepté ta demande';

/// The card on top: the ones behind it cannot be touched.
final _topCard = find.byType(HomeCardView).hitTestable();

/// The cross of the card on top.
final _cross = find.byTooltip('Masquer').hitTestable();

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

  testWidgets('shows the first card and the next two behind it',
      (tester) async {
    await pump(tester, () async => cards);

    expect(find.text(_firstTitle).hitTestable(), findsOneWidget);
    expect(find.byType(HomeCardView), findsNWidgets(3));
    // Behind the top card: neither touched nor read
    expect(find.text('Ajoute ton anniversaire').hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Ajoute ton anniversaire'), findsNothing);
  });

  testWidgets('one card behind it', (tester) async {
    await pump(tester, () async => cards.take(2).toList());

    expect(find.byType(HomeCardView), findsNWidgets(2));
  });

  testWidgets('a single card has none behind it', (tester) async {
    await pump(tester, () async => cards.take(1).toList());

    expect(find.byType(HomeCardView), findsOneWidget);
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
    expect(find.byType(HomeCardView), findsNWidgets(2));
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

    // The height ends at the one of the next card (none behind it), and
    // never went below it on the way
    final settled = tester.getSize(find.byType(HomeCardsSlot)).height;
    expect(find.text('Ajoute ton anniversaire'), findsOneWidget);
    expect(find.byType(HomeCardView), findsOneWidget);
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

    await tester.tap(_cross);
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
    walkLifecycleTo(AppLifecycleState.hidden);
    await tester.pump();

    verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
    expect(find.text('Annuler'), findsNothing);
    walkLifecycleTo(AppLifecycleState.resumed);
    await finish(tester);
  });

  testWidgets('a control center pull (inactive) keeps the Undo',
      (tester) async {
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);
    walkLifecycleTo(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.text('Annuler'), findsOneWidget);
    verifyNever(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    );
    walkLifecycleTo(AppLifecycleState.resumed);
    await finish(tester);
  });

  testWidgets('two taps on the cross before the rebuild give one snack-bar',
      (tester) async {
    await pump(tester, () async => cards);

    // No frame between the two taps: the card is still in the tree
    await tester.tap(_cross);
    await tester.tap(_cross);
    await letItLeave(tester);

    expect(find.text('Carte masquée'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    await finish(tester);
    verify(() => cardStates.dismiss('friend_accepted:a')).called(1);
  });

  testWidgets('a failed send brings the card back and shows the error',
      (tester) async {
    when(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    ).thenThrow(Exception('offline'));
    await pump(tester, () async => cards);

    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_firstTitle), findsOneWidget);
    expect(
      find.text('Une erreur est survenue, veuillez réessayer.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('several failed sends at once show a single error',
      (tester) async {
    when(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    ).thenThrow(Exception('offline'));
    await pump(tester, () async => cards);

    // Two swipes, the second card is on top once the first one is gone
    await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
    await letItLeave(tester);
    await tester.drag(_topCard, const Offset(-500, 0));
    await letItLeave(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    ).called(2);
    expect(
      find.text('Une erreur est survenue, veuillez réessayer.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Once it is gone, a new failure tells the user again
    await tester.drag(_topCard, const Offset(-500, 0));
    await letItLeave(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Une erreur est survenue, veuillez réessayer.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('the stack lets go of the app lifecycle when it leaves',
      (tester) async {
    var alive = 0;
    void track(ObjectEvent event) {
      if (event.object is! AppLifecycleListener) {
        return;
      }
      if (event is ObjectCreated) {
        alive++;
      } else if (event is ObjectDisposed) {
        alive--;
      }
    }

    FlutterMemoryAllocations.instance.addListener(track);
    addTearDown(() => FlutterMemoryAllocations.instance.removeListener(track));

    await pump(tester, () async => cards);
    expect(alive, greaterThan(0));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(alive, 0);
  });

  testWidgets('a postponed card shows again once it comes back after a reload',
      (tester) async {
    var loads = 0;
    // The first load has the card, the second (after the send) not, the third
    // (the next day) has it again
    await pump(tester, () async {
      loads++;
      return loads == 2 ? cards.skip(1).toList() : cards;
    });
    expect(find.text(_firstTitle), findsOneWidget);

    await tester.drag(find.text(_firstTitle), const Offset(500, 0));
    await letItLeave(tester);
    await finish(tester);
    expect(loads, 2);
    expect(find.text(_firstTitle), findsNothing);

    ProviderScope.containerOf(tester.element(find.byType(HomeCardsSlot)))
        .invalidate(homeCardsProvider);
    await tester.pumpAndSettle();

    expect(loads, 3);
    expect(find.text(_firstTitle), findsOneWidget);
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

        await tester.drag(_topCard, const Offset(-500, 0));
        await letItLeave(tester);
        expect(find.text('Carte masquée'), findsOneWidget);
        await finish(tester);
      });
    }

    final today = DateTime(fakeNow.year, fakeNow.month, fakeNow.day);
    HomeCardCandidate endingOn(DateTime lastDay) => HomeCardCandidate(
          type: 'friend_accepted',
          stateKey: 'friend_accepted:a',
          content: FriendAccepted(fakeFriendAppUser1, fakeNow),
          lastDay: lastDay,
        );

    testWidgets('a card that is gone tomorrow cannot be postponed',
        (tester) async {
      await pump(tester, () async => [endingOn(today)]);

      await tester.drag(find.byType(HomeCardView), const Offset(500, 0));
      await letItLeave(tester);

      expect(find.byType(HomeCardView), findsOneWidget);
      expect(find.textContaining('Reportée'), findsNothing);
    });

    testWidgets('a card still there tomorrow can be postponed', (tester) async {
      await pump(
        tester,
        () async =>
            [endingOn(DateTime(today.year, today.month, today.day + 1))],
      );

      await tester.drag(find.byType(HomeCardView), const Offset(500, 0));
      await letItLeave(tester);

      expect(find.text('Reportée à demain'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a card that is gone tomorrow offers no Later action',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, () async => [endingOn(today)]);

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.customSemanticsActions != null,
        ),
      );
      expect(
        [
          for (final action
              in semantics.properties.customSemanticsActions!.keys)
            action.label,
        ],
        ['Masquer'],
      );
      handle.dispose();
    });

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

  group('records only what is in front', () {
    // The first load shows `cards`, the next ones another top
    Future<List<HomeCardCandidate>> Function() reloadsWith(
      List<HomeCardCandidate> next,
    ) {
      var loads = 0;
      return () async => ++loads == 1 ? cards : next;
    }

    void reload(WidgetTester tester) {
      // Offstage under the other screen
      ProviderScope.containerOf(
        tester.element(find.byType(HomeCardsSlot, skipOffstage: false)),
      ).invalidate(homeCardsProvider);
    }

    testWidgets('not under another screen, then when it is back',
        (tester) async {
      await pump(tester, reloadsWith(cards.skip(1).toList()));
      verify(() => cardStates.recordShown('friend_accepted:a')).called(1);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        ),
      );
      await tester.pumpAndSettle();
      reload(tester);
      await tester.pumpAndSettle();

      verifyNever(() => cardStates.recordShown('onboarding:birthday'));

      navigator.pop();
      await tester.pumpAndSettle();

      verify(() => cardStates.recordShown('onboarding:birthday')).called(1);
    });

    testWidgets('not while the app is not in front, then on resume',
        (tester) async {
      await pump(tester, reloadsWith(cards.skip(1).toList()));
      verify(() => cardStates.recordShown('friend_accepted:a')).called(1);

      // Inactive still draws frames (hidden and paused do not)
      walkLifecycleTo(AppLifecycleState.inactive);
      reload(tester);
      await tester.pumpAndSettle();

      verifyNever(() => cardStates.recordShown('onboarding:birthday'));

      walkLifecycleTo(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      verify(() => cardStates.recordShown('onboarding:birthday')).called(1);
    });
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

  group('swipe', () {
    /// The top edge of the card on top: its two corners, as drawn.
    (Offset, Offset) topEdge(WidgetTester tester, Finder card) =>
        (tester.getTopLeft(card), tester.getTopRight(card));

    testWidgets('the card tilts to the side it is dragged to', (tester) async {
      await pump(tester, () async => cards);
      final card = find.ancestor(
        of: find.text(_firstTitle),
        matching: find.byType(HomeCardView),
      );

      final gesture = await tester.startGesture(tester.getCenter(card));
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      var (left, right) = topEdge(tester, card);
      expect(right.dy, greaterThan(left.dy));

      await gesture.moveBy(const Offset(-240, 0));
      await tester.pump();
      (left, right) = topEdge(tester, card);
      expect(right.dy, lessThan(left.dy));

      await gesture.up();
      await tester.pumpAndSettle();
      (left, right) = topEdge(tester, card);
      expect(right.dy, moreOrLessEquals(left.dy, epsilon: 0.5));
    });

    testWidgets('with less motion, the card slides without tilting',
        (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
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
      final card = find.ancestor(
        of: find.text(_firstTitle),
        matching: find.byType(HomeCardView),
      );
      final before = tester.getTopLeft(card);

      final gesture = await tester.startGesture(tester.getCenter(card));
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      final (left, right) = topEdge(tester, card);
      expect(left.dx, greaterThan(before.dx));
      expect(right.dy, moreOrLessEquals(left.dy, epsilon: 0.5));

      await gesture.up();
      await finish(tester);
    });

    testWidgets('the next card comes up and grows as the top one goes',
        (tester) async {
      await pump(tester, () async => cards);
      final top = find.ancestor(
        of: find.text(_firstTitle),
        matching: find.byType(HomeCardView),
      );
      final next = find.ancestor(
        of: find.text('Ajoute ton anniversaire'),
        matching: find.byType(HomeCardView),
      );
      double width(Finder card) =>
          tester.getTopRight(card).dx - tester.getTopLeft(card).dx;

      // At rest it is narrower, its bottom shows under the top card
      final atRest = width(next);
      expect(atRest, lessThan(width(top)));
      expect(
        tester.getBottomLeft(next).dy,
        greaterThan(tester.getBottomLeft(top).dy),
      );

      final gesture = await tester.startGesture(tester.getCenter(top));
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();
      expect(width(next), greaterThan(atRest));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(width(next), moreOrLessEquals(atRest, epsilon: 0.5));
    });

    testWidgets('a card that cannot be postponed resists to the right',
        (tester) async {
      // Closed for good: it can only be hidden
      await pump(tester, () async => [cards[1]]);
      final card = find.byType(HomeCardView);
      final before = tester.getTopLeft(card);

      final gesture = await tester.startGesture(tester.getCenter(card));
      await gesture.moveBy(const Offset(300, 0));
      await tester.pump();
      final moved = tester.getTopLeft(card).dx - before.dx;
      expect(moved, greaterThan(0));
      // Far less than the drag
      expect(moved, lessThan(100));
      expect(find.text('Plus tard'), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(card).dx,
        moreOrLessEquals(before.dx, epsilon: 0.5),
      );
      expect(find.text('Reportée à demain'), findsNothing);
    });

    testWidgets('"Annuler" brings the card back from the side it left by',
        (tester) async {
      await pump(tester, () async => cards);

      await tester.drag(find.text(_firstTitle), const Offset(-500, 0));
      await letItLeave(tester);
      final rest = tester.getTopLeft(_topCard);
      await tester.tap(find.text('Annuler'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final card = find.ancestor(
        of: find.text(_firstTitle),
        matching: find.byType(HomeCardView),
      );
      expect(tester.getTopLeft(card).dx, lessThan(rest.dx));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(card).dx,
        moreOrLessEquals(rest.dx, epsilon: 0.5),
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
