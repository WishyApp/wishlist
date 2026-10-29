import 'package:flutter/foundation.dart';

/// Key of one occurrence of a home card in `user_card_states`:
/// `type:id`, or `type:id:year` for a card that comes back every year.
String cardKey(String type, Object id, {int? year}) {
  return year == null ? '$type:$id' : '$type:$id:$year';
}

/// What a user saw and dismissed of one home card (table
/// `user_card_states`).
@immutable
class CardState {
  const CardState({
    required this.cardKey,
    required this.shownCount,
    this.lastShownAt,
    this.dismissedAt,
    this.snoozedUntil,
  });

  /// One row of `user_card_states`. Throws if a column is missing or has the
  /// wrong type.
  factory CardState.fromRow(Map<String, dynamic> row) {
    return CardState(
      cardKey: row['card_key'] as String,
      shownCount: row['shown_count'] as int,
      lastShownAt: _utc(row['last_shown_at']),
      dismissedAt: _utc(row['dismissed_at']),
      snoozedUntil: _utc(row['snoozed_until']),
    );
  }

  static DateTime? _utc(Object? value) {
    return value == null ? null : DateTime.parse(value as String).toUtc();
  }

  final String cardKey;
  final int shownCount;
  final DateTime? lastShownAt;
  final DateTime? dismissedAt;
  final DateTime? snoozedUntil;

  /// Dismissed, and not snoozed or snoozed until after [now]. A card
  /// dismissed without a snooze never comes back.
  bool isHidden(DateTime now) {
    if (dismissedAt == null) {
      return false;
    }
    final until = snoozedUntil;
    return until == null || until.isAfter(now);
  }
}
