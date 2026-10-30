import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/home/cards/card_selection.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/shared/models/card_state.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

import '../../../fixtures/fake_data.dart';

HomeCardCandidate candidate(
  String type,
  String stateKey, {
  DateTime? eventAt,
  bool dismissable = true,
  int? maxShows,
  bool isQueue = false,
}) {
  return HomeCardCandidate(
    type: type,
    stateKey: stateKey,
    content: const Onboarding(OnboardingStep.photo),
    eventAt: eventAt,
    dismissable: dismissable,
    maxShows: maxShows,
    isQueue: isQueue,
  );
}

HomeCardDefinition definition(String key, int priority) {
  return HomeCardDefinition(
    key: key,
    kind: HomeCardKind.computed,
    priority: priority,
  );
}

void main() {
  final now = DateTime.utc(2026, 10, 30, 10);
  final definitions = {
    'a': definition('a', 10),
    'b': definition('b', 20),
    'c': definition('c', 30),
  };

  List<String> select(
    List<HomeCardCandidate> candidates, {
    Map<String, CardState> states = const {},
    int maxCards = 3,
    Map<String, HomeCardDefinition>? defs,
  }) {
    return selectHomeCards(
      candidates: candidates,
      definitions: defs ?? definitions,
      states: states,
      maxCards: maxCards,
      now: now,
    ).map((card) => card.stateKey).toList();
  }

  test('sorts by priority, the smaller first', () {
    expect(
      select([
        candidate('c', 'c1'),
        candidate('a', 'a1'),
        candidate('b', 'b1'),
      ]),
      ['a1', 'b1', 'c1'],
    );
  });

  test('a tie is broken by the closest event, then by state key', () {
    expect(
      select(
        [
          candidate('a', 'a-late', eventAt: DateTime(2026, 12)),
          candidate('a', 'a-soon', eventAt: DateTime(2026, 11)),
          candidate('a', 'a-none'),
          candidate('a', 'a-b-key', eventAt: DateTime(2026, 11)),
        ],
        maxCards: 4,
      ),
      ['a-b-key', 'a-soon', 'a-late', 'a-none'],
    );
  });

  test('a card of a type without definition is dropped', () {
    expect(
      select([candidate('a', 'a1'), candidate('unknown', 'u1')]),
      ['a1'],
    );
  });

  test('a dismissed card without snooze is dropped', () {
    final states = {
      'a1': CardState(cardKey: 'a1', shownCount: 1, dismissedAt: fakeNow),
    };

    expect(
      select(
        [candidate('a', 'a1'), candidate('b', 'b1')],
        states: states,
      ),
      ['b1'],
    );
  });

  test('a card snoozed until tomorrow is hidden today and back tomorrow', () {
    final states = {
      'a1': CardState(
        cardKey: 'a1',
        shownCount: 1,
        dismissedAt: now,
        snoozedUntil: DateTime.utc(2026, 10, 31),
      ),
    };
    final cards = [candidate('a', 'a1')];

    expect(select(cards, states: states), isEmpty);
    expect(
      selectHomeCards(
        candidates: cards,
        definitions: definitions,
        states: states,
        maxCards: 3,
        now: DateTime.utc(2026, 10, 31, 0, 0, 1),
      ),
      hasLength(1),
    );
  });

  test('a card that cannot be dismissed stays even with a dismissed state', () {
    final states = {
      'a1': CardState(cardKey: 'a1', shownCount: 1, dismissedAt: fakeNow),
    };

    expect(
      select([candidate('a', 'a1', dismissable: false)], states: states),
      ['a1'],
    );
  });

  test('keeps maxCards cards out of five', () {
    expect(
      select(
        [
          for (var i = 1; i <= 5; i++) candidate('a', 'a$i'),
        ],
      ),
      ['a1', 'a2', 'a3'],
    );
  });

  test('a negative or zero maxCards gives nothing', () {
    expect(select([candidate('a', 'a1')], maxCards: 0), isEmpty);
    expect(select([candidate('a', 'a1')], maxCards: -1), isEmpty);
  });

  test('a card shown maxShows times is dropped', () {
    final states = {
      'a1': const CardState(cardKey: 'a1', shownCount: 3),
      'b1': const CardState(cardKey: 'b1', shownCount: 2),
    };

    expect(
      select(
        [
          candidate('a', 'a1', maxShows: 3),
          candidate('b', 'b1', maxShows: 3),
        ],
        states: states,
      ),
      ['b1'],
    );
  });

  test('a tie puts the closest event first, past or future', () {
    expect(
      select(
        [
          candidate('a', 'a-old', eventAt: DateTime.utc(2026, 10, 20)),
          candidate('a', 'a-future', eventAt: DateTime.utc(2026, 11, 5)),
          candidate('a', 'a-yesterday', eventAt: DateTime.utc(2026, 10, 29)),
        ],
      ),
      ['a-yesterday', 'a-future', 'a-old'],
    );
  });

  group('a queue of cards (the stale lists)', () {
    final today = DateTime(2026, 10, 30, 10);
    final queueDefs = {
      'a': definition('a', 10),
      'b': definition('b', 20),
      'q': definition('q', 60),
    };

    // q1 is the oldest, q4 the most recent.
    List<HomeCardCandidate> queue() => [
          for (var i = 4; i >= 1; i--)
            candidate(
              'q',
              'q$i',
              eventAt: DateTime(2026, 1, i),
              isQueue: true,
            ),
        ];

    List<String> run(
      List<HomeCardCandidate> candidates, {
      Map<String, CardState> states = const {},
      DateTime? at,
    }) {
      return selectHomeCards(
        candidates: candidates,
        definitions: queueDefs,
        states: states,
        maxCards: 3,
        now: at ?? today,
      ).map((card) => card.stateKey).toList();
    }

    CardState dismissed(String key, DateTime at) => CardState(
          cardKey: key,
          shownCount: 1,
          lastShownAt: at,
          dismissedAt: at,
          snoozedUntil: DateTime(2026, 12, 29),
        );

    CardState shown(String key, DateTime at) =>
        CardState(cardKey: key, shownCount: 1, lastShownAt: at);

    final morning = DateTime(2026, 10, 30, 8);

    test('three cards of the queue, the oldest event first', () {
      expect(run(queue().sublist(1)), ['q1', 'q2', 'q3']);
    });

    test('they fill the slots left by the more urgent cards', () {
      expect(
        run([candidate('a', 'a1'), candidate('b', 'b1'), ...queue()]),
        ['a1', 'b1', 'q1'],
      );
      expect(run([candidate('a', 'a1'), ...queue()]), ['a1', 'q1', 'q2']);
    });

    test('a card dismissed today leaves its slot empty, no refill', () {
      expect(
        run(
          queue(),
          states: {
            'q1': shown('q1', morning),
            'q2': dismissed('q2', morning),
            'q3': shown('q3', morning),
          },
        ),
        ['q1', 'q3'],
      );
    });

    test('the next day the fourth card comes in', () {
      final states = {
        'q1': shown('q1', morning),
        'q2': dismissed('q2', morning),
        'q3': shown('q3', morning),
      };

      expect(
        run(queue(), states: states, at: DateTime(2026, 10, 31, 0, 1)),
        ['q1', 'q3', 'q4'],
      );
    });

    test('a card dismissed yesterday does not block today', () {
      final yesterday = DateTime(2026, 10, 29, 23, 59);

      expect(
        run(queue(), states: {'q2': dismissed('q2', yesterday)}),
        ['q1', 'q3', 'q4'],
      );
    });

    test('a card dismissed today lets only the cards shown today stay', () {
      // q1 and q3 were in the stack this morning, q4 was not
      expect(
        run(
          queue(),
          states: {
            'q2': dismissed('q2', morning),
            'q3': shown('q3', morning),
            'q4': shown('q4', DateTime(2026, 10, 29, 9)),
          },
        ),
        ['q3'],
      );
    });

    test('a more urgent card dismissed later does not let a new card in', () {
      // Stack [a1, b1, q1]; q1 dismissed, then a1: q2 must not come in.
      expect(
        run(
          [candidate('a', 'a1'), candidate('b', 'b1'), ...queue()],
          states: {
            'a1': dismissed('a1', morning),
            'b1': shown('b1', morning),
            'q1': dismissed('q1', morning),
          },
        ),
        ['b1'],
      );
    });

    test('a card that is not stale anymore does not let a new one in', () {
      // Stack [q1, q2, q3]; q1 and q2 dismissed, then q2 left the queue
      // (the user added a wish): q4 must not come in.
      final candidates = [
        for (final card in queue())
          if (card.stateKey != 'q2') card,
      ];

      expect(
        run(
          candidates,
          states: {
            'q1': dismissed('q1', morning),
            'q2': dismissed('q2', morning),
            'q3': shown('q3', morning),
          },
        ),
        ['q3'],
      );
    });

    test('a dismissal of the queue does not affect the other cards', () {
      expect(
        run(
          [candidate('a', 'a1'), candidate('b', 'b1'), ...queue()],
          states: {'q1': dismissed('q1', morning)},
        ),
        ['a1', 'b1'],
      );
      expect(
        run(
          [candidate('a', 'a1'), candidate('b', 'b1'), ...queue()],
          states: {'a1': dismissed('a1', morning)},
        ),
        ['b1', 'q1', 'q2'],
      );
    });
  });
}
