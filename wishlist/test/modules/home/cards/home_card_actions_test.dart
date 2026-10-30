import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/home/cards/home_card_actions.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/modules/home/cards/stale_cards_day_store.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository_provider.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/lifecycle.dart';

class MockCardStateRepository extends Mock implements CardStateRepository {}

class MockBookedWishRemovalRepository extends Mock
    implements BookedWishRemovalRepository {}

HomeCardDefinition def(
  String key,
  int priority, [
  Map<String, dynamic> params = const {},
]) {
  return HomeCardDefinition(
    key: key,
    kind: key == 'home_stack' ? HomeCardKind.settings : HomeCardKind.computed,
    priority: priority,
    params: params,
  );
}

HomeCardCandidate photoCard() {
  return const HomeCardCandidate(
    type: 'onboarding',
    stateKey: 'onboarding:photo',
    content: Onboarding(OnboardingStep.photo),
  );
}

HomeCardCandidate removalCard() {
  return HomeCardCandidate(
    type: 'booked_wish_removed',
    stateKey: 'booked_wish_removed:7',
    content: BookedWishRemoved(
      BookedWishRemoval(
        id: 7,
        ownerId: fakeFriendUserId1,
        ownerPseudo: 'Alice',
        wishId: 99,
        wishName: 'Casque',
        quantity: 1,
        wishlistName: 'Anniversaire',
        removedAt: DateTime(2026, 10, 28),
      ),
      canOpenList: true,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var homeCardsLoads = 0;
  late MockCardStateRepository cardStates;
  late MockBookedWishRemovalRepository removals;
  // 10:00 on the 29th: "later" is the 30th at midnight, not 10:00.
  final now = DateTime(2026, 10, 29, 10);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  tearDown(() {
    // Leaves the shared binding as it was found
    walkLifecycleTo(AppLifecycleState.resumed);
  });

  setUp(() {
    homeCardsLoads = 0;
    cardStates = MockCardStateRepository();
    removals = MockBookedWishRemovalRepository();
    when(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    ).thenAnswer((_) async {});
    when(() => cardStates.recordShown(any())).thenAnswer((_) async {});
    when(() => removals.dismiss(any())).thenAnswer((_) async {});
  });

  /// Runs [body] in fake async with the notifier alive, then disposes it.
  void run(
    void Function(
      FakeAsync async,
      HomeCardActions actions,
      ProviderContainer container,
    ) body, {
    List<HomeCardDefinition>? definitions,
    List<Override> extra = const [],
    List<HomeCardCandidate> cards = const [],
  }) {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          ...extra,
          clockOverride(now),
          cardStateRepositoryProvider.overrideWithValue(cardStates),
          bookedWishRemovalRepositoryProvider.overrideWithValue(removals),
          homeCardsProvider.overrideWith((ref) async {
            homeCardsLoads++;
            return cards;
          }),
          homeCardDefinitionsProvider.overrideWith(
            (ref) async => {
              for (final d in definitions ??
                  [
                    def('home_stack', 0, {'later_days': 1}),
                    def('friend_birthday', 30, {
                      'reminder_days': [30, 7],
                    }),
                  ])
                d.key: d,
            },
          ),
        ],
      );
      container
        ..listen(homeCardActionsProvider, (_, __) {})
        ..listen(homeCardDefinitionsProvider, (_, __) {});
      async.flushMicrotasks();
      body(async, container.read(homeCardActionsProvider.notifier), container);
      container.dispose();
      async.flushMicrotasks();
    });
  }

  test('dismissNow hides for good at once, without waiting for a snack-bar',
      () {
    run((async, actions, container) {
      actions.dismissNow(photoCard());

      expect(container.read(homeCardActionsProvider), {'onboarding:photo'});
      async.flushMicrotasks();
      verify(() => cardStates.dismiss('onboarding:photo')).called(1);
      expect(homeCardsLoads, greaterThan(0));

      // Nothing more is sent later, nor by a second call
      actions.dismissNow(photoCard());
      async.elapse(const Duration(seconds: 10));
      verifyNever(
        () => cardStates.dismiss(
          'onboarding:photo',
          snoozeUntil: any(named: 'snoozeUntil'),
        ),
      );
    });
  });

  test('hide is sent for good by the fallback timer', () {
    run((async, actions, container) {
      actions.swipe(photoCard(), HomeCardSwipe.hide);

      expect(container.read(homeCardActionsProvider), {'onboarding:photo'});
      // The snack-bar ends at 4 s and commits; the timer is only a fallback
      async.elapse(homeCardUndoDuration);
      verifyNever(
        () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
      );

      async.elapse(const Duration(seconds: 1));
      verify(
        () => cardStates.dismiss('onboarding:photo'),
      ).called(1);
      // Still off the screen once sent
      expect(container.read(homeCardActionsProvider), {'onboarding:photo'});
    });
  });

  test('hide of a friend birthday comes back at the next reminder step', () {
    run((async, actions, container) {
      final card = HomeCardCandidate(
        type: 'friend_birthday',
        stateKey: 'friend_birthday:$fakeFriendUserId1@2026',
        content: FriendBirthdayToday(fakeFriendAppUser1),
        eventAt: DateTime(2026, 11, 5),
      );

      actions.swipe(card, HomeCardSwipe.hide);
      async.elapse(homeCardCommitFallback);

      // The J-7 step is this morning, already past: the next one is the day.
      verify(
        () => cardStates.dismiss(
          card.stateKey,
          snoozeUntil: DateTime(2026, 11, 5),
        ),
      ).called(1);
    });
  });

  test('later is postponed to the start of the next local day', () {
    run((async, actions, container) {
      actions.swipe(photoCard(), HomeCardSwipe.later);
      async.elapse(homeCardCommitFallback);

      verify(
        () => cardStates.dismiss(
          'onboarding:photo',
          snoozeUntil: DateTime(2026, 10, 30),
        ),
      ).called(1);
    });
  });

  test('later follows later_days of home_stack', () {
    run(
      (async, actions, container) {
        expect(actions.laterDays, 3);
        actions.swipe(photoCard(), HomeCardSwipe.later);
        async.elapse(homeCardCommitFallback);

        verify(
          () => cardStates.dismiss(
            'onboarding:photo',
            snoozeUntil: DateTime(2026, 11),
          ),
        ).called(1);
      },
      definitions: [
        def('home_stack', 0, {'later_days': 3}),
      ],
    );
  });

  test('undo before the end sends nothing and brings the card back', () {
    run((async, actions, container) {
      actions.swipe(photoCard(), HomeCardSwipe.hide);
      async.elapse(const Duration(seconds: 2));
      actions.undo('onboarding:photo');

      expect(container.read(homeCardActionsProvider), isEmpty);
      async.elapse(const Duration(seconds: 10));
      verifyNever(
        () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
      );
    });
  });

  test('leaving the screen sends what is waiting at once', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          clockOverride(now),
          cardStateRepositoryProvider.overrideWithValue(cardStates),
          bookedWishRemovalRepositoryProvider.overrideWithValue(removals),
          homeCardsProvider.overrideWith((ref) async => const []),
          homeCardDefinitionsProvider.overrideWith(
            (ref) async => {'home_stack': def('home_stack', 0)},
          ),
        ],
      );
      final subscription =
          container.listen(homeCardActionsProvider, (_, __) {});
      container
          .read(homeCardActionsProvider.notifier)
          .swipe(photoCard(), HomeCardSwipe.hide);
      async.elapse(const Duration(seconds: 1));
      verifyNever(
        () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
      );

      // The screen is left: nothing listens to the notifier any more
      subscription.close();
      async.elapse(Duration.zero);

      verify(
        () => cardStates.dismiss('onboarding:photo'),
      ).called(1);
      // The timer is gone: no second send
      async.elapse(const Duration(seconds: 10));
      verifyNoMoreInteractions(cardStates);
      container.dispose();
    });
  });

  test('a removal alert is closed on its own table, not as a card state', () {
    run((async, actions, container) {
      actions.swipe(removalCard(), HomeCardSwipe.hide);
      async.elapse(homeCardCommitFallback);

      verify(() => removals.dismiss(7)).called(1);
      verifyNever(
        () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
      );
    });
  });

  test('records a card once, and never the optional window', () {
    run((async, actions, container) {
      actions
        ..recordShown('onboarding:birthday')
        ..recordShown('onboarding:birthday')
        ..recordShown('friend_accepted:a');
      async.flushMicrotasks();

      verify(() => cardStates.recordShown('onboarding:birthday')).called(1);
      verify(() => cardStates.recordShown('friend_accepted:a')).called(1);
      verifyNever(
        () => cardStates.recordShown('onboarding:optional_window'),
      );
    });
  });

  test('a failing send does not throw, brings the card back and tells', () {
    when(
      () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
    ).thenThrow(Exception('offline'));

    run((async, actions, container) {
      final failures = <HomeCardSendFailure?>[];
      container.listen(
        homeCardSendFailureProvider,
        (_, next) => failures.add(next),
      );
      actions.swipe(photoCard(), HomeCardSwipe.hide);
      async.elapse(homeCardCommitFallback);
      async.flushMicrotasks();

      // Not hidden for the session while it was never closed
      expect(container.read(homeCardActionsProvider), isEmpty);
      expect(failures, hasLength(1));
      expect(failures.single!.error, isA<Exception>());
      // And it can be swiped again
      expect(actions.swipe(photoCard(), HomeCardSwipe.hide), isTrue);
    });
  });

  test('a failing send of an alert brings it back too', () {
    when(() => removals.dismiss(any())).thenThrow(Exception('offline'));

    run((async, actions, container) {
      actions.swipe(removalCard(), HomeCardSwipe.hide);
      async.elapse(homeCardCommitFallback);
      async.flushMicrotasks();

      expect(container.read(homeCardActionsProvider), isEmpty);
    });
  });

  test('commit sends at once, and the fallback timer sends nothing more', () {
    run((async, actions, container) {
      actions.swipe(photoCard(), HomeCardSwipe.hide);
      async.elapse(const Duration(seconds: 4));
      actions.commit('onboarding:photo');
      async.flushMicrotasks();

      verify(() => cardStates.dismiss('onboarding:photo')).called(1);
      async.elapse(const Duration(seconds: 10));
      verifyNoMoreInteractions(cardStates);
    });
  });

  test('without autoCommit nothing is sent until commit, leaving or lifecycle',
      () {
    run((async, actions, container) {
      actions.swipe(photoCard(), HomeCardSwipe.hide, autoCommit: false);
      async.elapse(const Duration(minutes: 5));
      verifyNever(
        () => cardStates.dismiss(any(), snoozeUntil: any(named: 'snoozeUntil')),
      );
    });
    // Disposed by run: sent then
    verify(() => cardStates.dismiss('onboarding:photo')).called(1);
  });

  test('a second swipe of the same card changes nothing', () {
    run((async, actions, container) {
      actions.swipe(photoCard(), HomeCardSwipe.hide);
      async.elapse(const Duration(seconds: 2));
      actions.swipe(photoCard(), HomeCardSwipe.later);
      async.elapse(homeCardCommitFallback);
      // Even after the send
      actions.swipe(photoCard(), HomeCardSwipe.later);
      async.elapse(homeCardCommitFallback);

      // Only the first swipe (hide) was sent, once
      verify(() => cardStates.dismiss('onboarding:photo')).called(1);
      verifyNoMoreInteractions(cardStates);
    });
  });

  test('a send reloads the cards', () {
    run((async, actions, container) {
      container.listen(homeCardsProvider, (_, __) {});
      async.flushMicrotasks();
      expect(homeCardsLoads, 1);

      actions.swipe(photoCard(), HomeCardSwipe.hide);
      async.elapse(homeCardCommitFallback);

      expect(homeCardsLoads, 2);
    });
  });

  test('swipe tells whether it took the card', () {
    run((async, actions, container) {
      expect(actions.swipe(photoCard(), HomeCardSwipe.hide), isTrue);
      expect(actions.swipe(photoCard(), HomeCardSwipe.later), isFalse);
      async.elapse(homeCardCommitFallback);
      // Sent: still off the screen, still refused
      expect(actions.swipe(photoCard(), HomeCardSwipe.hide), isFalse);
    });
  });

  group('a stale card', () {
    final staleCard2 = HomeCardCandidate(
      type: 'stale_wishlist',
      stateKey: 'stale_wishlist:2',
      content: StaleWishlist(fakeWishlist2, 4),
      isQueue: true,
    );
    final staleCard = HomeCardCandidate(
      type: 'stale_wishlist',
      stateKey: 'stale_wishlist:1',
      content: StaleWishlist(fakeWishlist1, 4),
      isQueue: true,
    );
    late StaleCardsDayStore store;

    setUp(() => store = StaleCardsDayStore());

    void runStale(
      void Function(FakeAsync async, HomeCardActions actions) body,
    ) {
      run(
        (async, actions, container) => body(async, actions),
        extra: [
          supabaseClientOverride(userId: fakeCurrentUserId),
          staleCardsDayStoreProvider.overrideWithValue(store),
        ],
      );
    }

    bool dismissed() => store.dayOf(fakeCurrentUserId, now).dismissed;

    for (final swipe in HomeCardSwipe.values) {
      test('swiped ($swipe) blocks the other stale lists before sending', () {
        runStale((async, actions) {
          actions.swipe(staleCard, swipe);

          expect(dismissed(), isTrue);
          verifyNever(
            () => cardStates.dismiss(
              any(),
              snoozeUntil: any(named: 'snoozeUntil'),
            ),
          );
        });
      });
    }

    test('swiped keeps the stale cards of the stack on screen as shown', () {
      run(
        (async, actions, container) {
          container.read(homeCardsProvider);
          async.flushMicrotasks();

          actions.swipe(staleCard, HomeCardSwipe.hide);

          expect(
            store.dayOf(fakeCurrentUserId, now).shownKeys,
            {'stale_wishlist:1', 'stale_wishlist:2'},
          );
        },
        extra: [
          supabaseClientOverride(userId: fakeCurrentUserId),
          staleCardsDayStoreProvider.overrideWithValue(store),
        ],
        cards: [staleCard, staleCard2],
      );
    });

    test('dismissed at once blocks them too', () {
      runStale((async, actions) {
        actions.dismissNow(staleCard);

        expect(dismissed(), isTrue);
      });
    });

    test('another card does not block them', () {
      runStale((async, actions) {
        actions.swipe(photoCard(), HomeCardSwipe.hide);

        expect(dismissed(), isFalse);
      });
    });
  });

  group('release', () {
    test('a sent card comes back once a reload no longer holds it', () {
      run((async, actions, container) {
        actions.swipe(photoCard(), HomeCardSwipe.later);
        async.elapse(homeCardCommitFallback);

        // The reload that still holds it (read before the send) changes nothing
        actions.release({'onboarding:photo'});
        expect(container.read(homeCardActionsProvider), {'onboarding:photo'});

        // The next day's reload: gone, then back
        actions.release(const {});
        expect(container.read(homeCardActionsProvider), isEmpty);
        expect(actions.swipe(photoCard(), HomeCardSwipe.later), isTrue);
      });
    });

    test('a card still waiting to be sent is never released', () {
      run((async, actions, container) {
        actions.swipe(photoCard(), HomeCardSwipe.hide);

        actions.release(const {});

        expect(container.read(homeCardActionsProvider), {'onboarding:photo'});
      });
    });

    test('a card whose send is in flight is never released', () {
      run((async, actions, container) {
        final sending = Completer<void>();
        when(
          () => cardStates.dismiss(
            any(),
            snoozeUntil: any(named: 'snoozeUntil'),
          ),
        ).thenAnswer((_) => sending.future);

        actions.swipe(photoCard(), HomeCardSwipe.later);
        async.elapse(homeCardCommitFallback);

        // A reload that does not hold it comes while the request is out
        actions.release(const {});
        expect(container.read(homeCardActionsProvider), {'onboarding:photo'});

        sending.complete();
        async.flushMicrotasks();
        expect(container.read(homeCardActionsProvider), {'onboarding:photo'});

        actions.release(const {});
        expect(container.read(homeCardActionsProvider), isEmpty);
      });
    });
  });

  test('an alert closed does not reload the cards, its stream does', () {
    run((async, actions, container) {
      container.listen(homeCardsProvider, (_, __) {});
      async.flushMicrotasks();
      expect(homeCardsLoads, 1);

      actions.swipe(removalCard(), HomeCardSwipe.hide);
      async.elapse(homeCardCommitFallback);

      verify(() => removals.dismiss(7)).called(1);
      expect(homeCardsLoads, 1);
    });
  });

  test('later_days is at least one day', () {
    run(
      (async, actions, container) {
        expect(actions.laterDays, 1);
        actions.swipe(photoCard(), HomeCardSwipe.later);
        async.elapse(homeCardCommitFallback);

        verify(
          () => cardStates.dismiss(
            'onboarding:photo',
            snoozeUntil: DateTime(2026, 10, 30),
          ),
        ).called(1);
      },
      definitions: [
        def('home_stack', 0, {'later_days': 0}),
      ],
    );
  });

  group('app lifecycle', () {
    void changeTo(FakeAsync async, AppLifecycleState state) {
      walkLifecycleTo(state);
      async.flushMicrotasks();
    }

    test('inactive alone (control center, call banner) sends nothing', () {
      run((async, actions, container) {
        actions.swipe(photoCard(), HomeCardSwipe.hide);
        changeTo(async, AppLifecycleState.inactive);

        verifyNever(
          () => cardStates.dismiss(
            any(),
            snoozeUntil: any(named: 'snoozeUntil'),
          ),
        );
        // The snack-bar goes on: it commits itself when it ends
        async.elapse(homeCardCommitFallback);
        verify(() => cardStates.dismiss('onboarding:photo')).called(1);
      });
    });

    test('hidden sends what is waiting and keeps the cards hidden', () {
      run((async, actions, container) {
        actions.swipe(photoCard(), HomeCardSwipe.hide);
        async.elapse(const Duration(seconds: 1));

        changeTo(async, AppLifecycleState.hidden);

        verify(() => cardStates.dismiss('onboarding:photo')).called(1);
        expect(container.read(homeCardActionsProvider), {'onboarding:photo'});
        // No second send from the timer
        async.elapse(const Duration(seconds: 10));
        verifyNoMoreInteractions(cardStates);
      });
    });

    test('hidden and paused send too', () {
      run((async, actions, container) {
        changeTo(async, AppLifecycleState.inactive);
        actions.swipe(photoCard(), HomeCardSwipe.hide);
        changeTo(async, AppLifecycleState.hidden);
        verify(() => cardStates.dismiss('onboarding:photo')).called(1);

        actions.swipe(removalCard(), HomeCardSwipe.hide);
        changeTo(async, AppLifecycleState.paused);
        verify(() => removals.dismiss(7)).called(1);
      });
    });

    test('detached sends what is waiting', () {
      run((async, actions, container) {
        // Already paused: only the detach is left to tell the app is going
        changeTo(async, AppLifecycleState.paused);
        actions.swipe(photoCard(), HomeCardSwipe.hide);
        verifyNever(() => cardStates.dismiss(any()));

        changeTo(async, AppLifecycleState.detached);

        verify(() => cardStates.dismiss('onboarding:photo')).called(1);
      });
    });

    test('a swipe after coming back is sent again as usual', () {
      run((async, actions, container) {
        changeTo(async, AppLifecycleState.inactive);
        changeTo(async, AppLifecycleState.resumed);

        actions.swipe(photoCard(), HomeCardSwipe.hide);
        async.elapse(homeCardCommitFallback);

        verify(() => cardStates.dismiss('onboarding:photo')).called(1);
      });
    });
  });

  group('snack-bar closer', () {
    test('is called when the commit does not come from the snack-bar', () {
      run((async, actions, container) {
        var closed = 0;
        actions.swipe(photoCard(), HomeCardSwipe.hide);
        actions.attachCloser('onboarding:photo', () => closed++);

        async.elapse(homeCardCommitFallback);

        expect(closed, 1);
      });
    });

    test('is called on lifecycle and on leaving, not on commit or undo', () {
      var closedByLifecycle = 0;
      var closedByCommit = 0;
      var closedByUndo = 0;
      var closedOnLeave = 0;
      run((async, actions, container) {
        actions.swipe(photoCard(), HomeCardSwipe.hide);
        actions.attachCloser('onboarding:photo', () => closedByCommit++);
        actions.commit('onboarding:photo');

        actions.swipe(removalCard(), HomeCardSwipe.hide);
        actions.attachCloser(
          'booked_wish_removed:7',
          () => closedByUndo++,
        );
        actions.undo('booked_wish_removed:7');

        const other = HomeCardCandidate(
          type: 'onboarding',
          stateKey: 'onboarding:birthday',
          content: Onboarding(OnboardingStep.birthday),
        );
        actions.swipe(other, HomeCardSwipe.hide);
        actions.attachCloser('onboarding:birthday', () => closedByLifecycle++);
        walkLifecycleTo(AppLifecycleState.hidden);
        async.flushMicrotasks();

        actions.swipe(removalCard(), HomeCardSwipe.hide);
        actions.attachCloser(
          'booked_wish_removed:7',
          () => closedOnLeave++,
        );
      });

      expect(closedByCommit, 0);
      expect(closedByUndo, 0);
      expect(closedByLifecycle, 1);
      expect(closedOnLeave, 1);
    });

    test('a closer attached after the commit is called at once', () {
      run((async, actions, container) {
        var closed = 0;
        actions.swipe(photoCard(), HomeCardSwipe.hide);
        async.elapse(homeCardCommitFallback);

        actions.attachCloser('onboarding:photo', () => closed++);

        expect(closed, 1);
      });
    });
  });
}
