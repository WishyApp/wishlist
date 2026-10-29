import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/models/card_state.dart';

void main() {
  final now = DateTime.utc(2026, 11, 1, 12);

  CardState state({DateTime? dismissedAt, DateTime? snoozedUntil}) {
    return CardState(
      cardKey: 'booked_reminder:1',
      shownCount: 1,
      dismissedAt: dismissedAt,
      snoozedUntil: snoozedUntil,
    );
  }

  group('isHidden', () {
    test('is true when dismissed without a snooze', () {
      expect(state(dismissedAt: now).isHidden(now), isTrue);
    });

    test('is true while the snooze is in the future', () {
      final snoozed = state(
        dismissedAt: now,
        snoozedUntil: now.add(const Duration(days: 1)),
      );
      expect(snoozed.isHidden(now), isTrue);
    });

    test('is false when the snooze ends exactly now', () {
      expect(state(dismissedAt: now, snoozedUntil: now).isHidden(now), isFalse);
    });

    test('is false once the snooze is over', () {
      final snoozed = state(
        dismissedAt: now,
        snoozedUntil: now.subtract(const Duration(days: 1)),
      );
      expect(snoozed.isHidden(now), isFalse);
    });

    test('is false when never dismissed', () {
      expect(state().isHidden(now), isFalse);
    });
  });

  test('fromRow reads every column, dates in UTC', () {
    final cardState = CardState.fromRow(const <String, dynamic>{
      'user_id': 'user-1',
      'card_key': 'stale_wishlist:9',
      'shown_count': 3,
      'last_shown_at': '2026-10-30T10:00:00+00:00',
      'dismissed_at': '2026-10-30T11:00:00+00:00',
      'snoozed_until': '2026-12-29T11:00:00+00:00',
    });

    expect(cardState.cardKey, 'stale_wishlist:9');
    expect(cardState.shownCount, 3);
    expect(cardState.lastShownAt, DateTime.utc(2026, 10, 30, 10));
    expect(cardState.lastShownAt!.isUtc, isTrue);
    expect(cardState.dismissedAt, DateTime.utc(2026, 10, 30, 11));
    expect(cardState.snoozedUntil, DateTime.utc(2026, 12, 29, 11));
  });

  test('fromRow keeps null dates null', () {
    final cardState = CardState.fromRow(const <String, dynamic>{
      'card_key': 'christmas:2026',
      'shown_count': 0,
      'last_shown_at': null,
      'dismissed_at': null,
      'snoozed_until': null,
    });

    expect(cardState.lastShownAt, isNull);
    expect(cardState.dismissedAt, isNull);
    expect(cardState.snoozedUntil, isNull);
  });

  group('cardKey', () {
    test('joins the type and the id', () {
      expect(cardKey('booked_reminder', 4512), 'booked_reminder:4512');
    });

    test('appends the year', () {
      expect(
        cardKey('friend_birthday', 'abc', year: 2026),
        'friend_birthday:abc:2026',
      );
    });
  });
}
