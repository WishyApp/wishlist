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
}) {
  return HomeCardCandidate(
    type: type,
    stateKey: stateKey,
    content: const Onboarding(OnboardingStep.photo),
    eventAt: eventAt,
    dismissable: dismissable,
    maxShows: maxShows,
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
}
