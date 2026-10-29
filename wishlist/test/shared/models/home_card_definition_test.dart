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
    'event_on': null,
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
        'event_on': '2026-12-10',
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
      expect(card.eventOn, DateTime(2026, 12, 10));
      expect(card.startsAt, DateTime.utc(2026, 12, 2, 23));
      expect(card.endsAt, DateTime.utc(2026, 12, 10, 22, 59));
      expect(card.title, {'fr': 'Du nouveau', 'en': 'News'});
      expect(card.body, {'fr': 'Corps', 'en': 'Body'});
      expect(card.ctaLabel, {'fr': 'Voir', 'en': 'Look'});
      expect(() => card.title!['fr'] = 'x', throwsUnsupportedError);
      expect(() => card.params['a'] = 1, throwsUnsupportedError);
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

    test('throws on an unknown kind', () {
      expect(
        () => HomeCardDefinition.fromRow(_row('x', kind: 'banner')),
        throwsFormatException,
      );
    });

    test('throws on malformed texts and params', () {
      expect(
        () => HomeCardDefinition.fromRow({
          ..._row('x'),
          'title': const <String>[],
        }),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => HomeCardDefinition.fromRow({
          ..._row('x'),
          'cta_label': const {'fr': null},
        }),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => HomeCardDefinition.fromRow({..._row('x'), 'params': '[]'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('a malformed list param gives an empty list', () {
      final card = _christmas(params: {'reminder_days': 'soon'});

      expect(card.intListParam('reminder_days'), isEmpty);
    });
  });

  group('localized texts', () {
    HomeCardDefinition card({
      Map<String, String>? title,
      Map<String, String>? body,
      Map<String, String>? ctaLabel,
    }) =>
        HomeCardDefinition(
          key: 'x',
          kind: HomeCardKind.editorial,
          priority: 1,
          title: title,
          body: body,
          ctaLabel: ctaLabel,
        );
    const both = {'fr': 'Noël', 'en': 'Christmas'};

    test('returns the requested language', () {
      expect(card(title: both).localizedTitle('fr'), 'Noël');
      expect(card(body: both).localizedBody('en'), 'Christmas');
      expect(card(ctaLabel: both).localizedCtaLabel('en'), 'Christmas');
    });

    test('falls back to english', () {
      expect(card(title: both).localizedTitle('de'), 'Christmas');
      expect(card(body: both).localizedBody('de'), 'Christmas');
      expect(card(ctaLabel: both).localizedCtaLabel('de'), 'Christmas');
    });

    test('falls back to french without english', () {
      expect(card(title: const {'fr': 'Noël'}).localizedTitle('de'), 'Noël');
    });

    test('returns null without texts', () {
      expect(card().localizedTitle('fr'), isNull);
      expect(card().localizedBody('fr'), isNull);
      expect(card().localizedCtaLabel('fr'), isNull);
    });
  });

  group('nextReminderAfter', () {
    final card = _christmas();
    final christmas = DateTime(2026, 12, 25);

    test('hidden on 26 November, comes back on 18 December', () {
      expect(
        card.nextReminderAfter(
          eventOn: christmas,
          dismissedAt: DateTime(2026, 11, 26, 9),
        ),
        DateTime(2026, 12, 18),
      );
    });

    test('hidden on 19 December, comes back on the day', () {
      expect(
        card.nextReminderAfter(
          eventOn: christmas,
          dismissedAt: DateTime(2026, 12, 19, 9),
        ),
        DateTime(2026, 12, 25),
      );
    });

    test('hidden on the day, never comes back this year', () {
      expect(
        card.nextReminderAfter(
          eventOn: christmas,
          dismissedAt: DateTime(2026, 12, 25, 9),
        ),
        isNull,
      );
    });
  });

  group('event day', () {
    test('a reminder step can fall in the previous year', () {
      final card = _christmas(
        params: {
          'reminder_days': [30],
        },
      );

      expect(
        card.nextReminderAfter(
          eventOn: DateTime(2027, 1, 3),
          dismissedAt: DateTime(2026, 11, 2),
        ),
        DateTime(2026, 12, 4),
      );
    });

    test('10 December stays 10 December in any timezone', () {
      final card = HomeCardDefinition.fromRow({
        ..._row('x', kind: 'editorial'),
        'event_on': '2026-12-10',
      });

      expect(card.eventOn, DateTime(2026, 12, 10));
      expect(card.eventOn!.isUtc, isFalse);
    });

    test('reminder steps and highlight follow the day, not an instant', () {
      final card = _christmas();
      final eventOn = DateTime(2026, 12, 10);

      expect(
        card.nextReminderAfter(
          eventOn: eventOn,
          dismissedAt: DateTime(2026, 11, 20),
        ),
        DateTime(2026, 12, 3),
      );
      expect(
        card.isHighlighted(eventOn: eventOn, now: DateTime(2026, 12, 10, 23)),
        isTrue,
      );
      expect(
        card.isHighlighted(eventOn: eventOn, now: DateTime(2026, 12, 11, 1)),
        isFalse,
      );
    });
  });

  group('isHighlighted', () {
    final now = DateTime(2026, 12, 1, 12);

    test('true within the highlight window', () {
      expect(
        _christmas().isHighlighted(
          eventOn: now.add(const Duration(days: 5)),
          now: now,
        ),
        isTrue,
      );
    });

    test('false beyond the window', () {
      expect(
        _christmas().isHighlighted(
          eventOn: now.add(const Duration(days: 8)),
          now: now,
        ),
        isFalse,
      );
    });

    test('true on the event day itself, later that day', () {
      expect(
        _christmas().isHighlighted(
          eventOn: DateTime(2026, 12, 1, 20),
          now: now,
        ),
        isTrue,
      );
    });

    test('true 7 days ahead, false 8 days ahead', () {
      expect(
        _christmas().isHighlighted(eventOn: DateTime(2026, 12, 8), now: now),
        isTrue,
      );
      expect(
        _christmas().isHighlighted(eventOn: DateTime(2026, 12, 9), now: now),
        isFalse,
      );
    });

    test('false the day after the event', () {
      expect(
        _christmas().isHighlighted(
          eventOn: DateTime(2026, 11, 30, 23),
          now: now,
        ),
        isFalse,
      );
    });

    test('false once the event is past', () {
      expect(
        _christmas().isHighlighted(
          eventOn: now.subtract(const Duration(days: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('honours a smaller highlight_days', () {
      expect(
        _christmas(params: {'highlight_days': 3}).isHighlighted(
          eventOn: now.add(const Duration(days: 5)),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
