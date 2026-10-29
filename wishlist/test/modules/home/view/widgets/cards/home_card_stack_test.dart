import 'dart:async';

import 'package:flutter/material.dart';
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
    Future<List<HomeCardCandidate>> Function() load,
  ) async {
    await tester.pumpApp(
      const Scaffold(
        body: SafeArea(child: SingleChildScrollView(child: HomeCardsSlot())),
      ),
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
}
