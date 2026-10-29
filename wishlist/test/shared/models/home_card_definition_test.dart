import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

Map<String, dynamic> _row(
  String key, {
  String kind = 'computed',
  int priority = 40,
  Map<String, dynamic> params = const {},
}) {
  return {
    'key': key,
    'kind': kind,
    'enabled': true,
    'priority': priority,
    'params': params,
    'event_at': null,
    'starts_at': null,
    'ends_at': null,
    'title': null,
    'body': null,
    'cta_label': null,
    'cta_route': null,
    'illustration': null,
    'updated_at': '2026-10-30T10:00:00+00:00',
  };
}

HomeCardDefinition _christmas({Map<String, dynamic>? params}) {
  return HomeCardDefinition.fromRow(
    _row(
      'christmas',
      params: params ??
          {
            'reminder_days': [30, 7],
            'highlight_days': 7,
            'keywords': ['noel', 'christmas', 'xmas'],
          },
    ),
  );
}

void main() {
  group('fromRow', () {
    test('reads a complete editorial row, dates in UTC', () {
      final card = HomeCardDefinition.fromRow({
        ..._row('new_feature_2026_12', kind: 'editorial', priority: 45),
        'event_at': '2026-12-10T00:00:00+01:00',
        'starts_at': '2026-12-03T00:00:00+01:00',
        'ends_at': '2026-12-10T23:59:00+01:00',
        'title': const {'fr': 'Du nouveau', 'en': 'News'},
        'body': const {'fr': 'Corps', 'en': 'Body'},
        'cta_label': const {'fr': 'Voir', 'en': 'Look'},
        'cta_route': '/',
        'illustration': 'gift',
      });

      expect(card.key, 'new_feature_2026_12');
      expect(card.kind, HomeCardKind.editorial);
      expect(card.priority, 45);
      expect(card.eventAt, DateTime.utc(2026, 12, 9, 23));
      expect(card.startsAt, DateTime.utc(2026, 12, 2, 23));
      expect(card.endsAt, DateTime.utc(2026, 12, 10, 22, 59));
      expect(card.eventAt!.isUtc, isTrue);
      expect(card.title, {'fr': 'Du nouveau', 'en': 'News'});
      expect(card.body, {'fr': 'Corps', 'en': 'Body'});
      expect(card.ctaLabel, {'fr': 'Voir', 'en': 'Look'});
      expect(card.ctaRoute, '/');
      expect(card.illustration, 'gift');
    });

    test('reads the christmas row and its params', () {
      final card = _christmas();

      expect(card.kind, HomeCardKind.computed);
      expect(card.intListParam('reminder_days'), [30, 7]);
      expect(card.intParam('highlight_days', 0), 7);
      expect(card.intParam('absent', 5), 5);
      expect(card.intListParam('absent'), isEmpty);
      expect(card.stringListParam('keywords'), ['noel', 'christmas', 'xmas']);
      expect(card.stringListParam('absent'), isEmpty);
      expect(card.title, isNull);
    });

    test('reads the home_stack settings row', () {
      final card = HomeCardDefinition.fromRow(
        _row(
          'home_stack',
          kind: 'settings',
          priority: 0,
          params: {'max_cards': 3, 'later_days': 1},
        ),
      );

      expect(card.kind, HomeCardKind.settings);
      expect(card.intParam('max_cards', 0), 3);
    });

    test('a malformed list param gives an empty list', () {
      final card = _christmas(params: {'reminder_days': 'soon'});

      expect(card.intListParam('reminder_days'), isEmpty);
    });
  });

  group('localized', () {
    final card = _christmas();
    const texts = {'fr': 'Noël', 'en': 'Christmas'};

    test('returns the requested language', () {
      expect(card.localized(texts, 'en'), 'Christmas');
    });

    test('falls back to french', () {
      expect(card.localized(texts, 'de'), 'Noël');
    });

    test('returns null without texts', () {
      expect(card.localized(null, 'fr'), isNull);
    });
  });

  group('nextReminderAfter', () {
    final card = _christmas();
    final christmas = DateTime(2026, 12, 25);

    test('hidden on 26 November, comes back on 18 December', () {
      expect(
        card.nextReminderAfter(
          eventAt: christmas,
          dismissedAt: DateTime(2026, 11, 26, 9),
        ),
        DateTime(2026, 12, 18),
      );
    });

    test('hidden on 19 December, comes back on the day', () {
      expect(
        card.nextReminderAfter(
          eventAt: christmas,
          dismissedAt: DateTime(2026, 12, 19, 9),
        ),
        DateTime(2026, 12, 25),
      );
    });

    test('hidden on the day, never comes back this year', () {
      expect(
        card.nextReminderAfter(
          eventAt: christmas,
          dismissedAt: DateTime(2026, 12, 25, 9),
        ),
        isNull,
      );
    });
  });

  group('isHighlighted', () {
    final now = DateTime(2026, 12, 1, 12);

    test('true within the highlight window', () {
      expect(
        _christmas().isHighlighted(
          eventAt: now.add(const Duration(days: 5)),
          now: now,
        ),
        isTrue,
      );
    });

    test('false beyond the window', () {
      expect(
        _christmas().isHighlighted(
          eventAt: now.add(const Duration(days: 8)),
          now: now,
        ),
        isFalse,
      );
    });

    test('false once the event is past', () {
      expect(
        _christmas().isHighlighted(
          eventAt: now.subtract(const Duration(days: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('honours a smaller highlight_days', () {
      expect(
        _christmas(params: {'highlight_days': 3}).isHighlighted(
          eventAt: now.add(const Duration(days: 5)),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
