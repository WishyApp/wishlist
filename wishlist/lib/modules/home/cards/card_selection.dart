import 'dart:math';

import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/shared/models/card_state.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

/// The cards to show, at most [maxCards], most urgent first.
///
/// Drops a card whose type has no definition (disabled), a dismissable card
/// that is hidden at [now] (dismissed and not snoozed, or still snoozed), and
/// a card shown `maxShows` times already. Sorts by the `priority` of the
/// definition (smaller first), then by the `eventAt` closest to [now], past or
/// future (none last), so that the most recent past event comes first, then
/// by state key so that the order is stable. Among the cards of a queue
/// (`isQueue`) the oldest event comes first instead.
///
/// No refill: once a card of a queue was dismissed on the local day of [now],
/// only the cards of the queue already shown that day (`lastShownAt`, recorded
/// by the provider for each card of the stack) may be in the stack: the queue
/// may shrink until tomorrow, never gain a card. The dismissed cards leave
/// their slot empty: the stack is computed as if they were not hidden, then
/// they are removed. Limit: a dismissed card whose list is gone is no
/// candidate, so its dismissal is not seen.
List<HomeCardCandidate> selectHomeCards({
  required List<HomeCardCandidate> candidates,
  required Map<String, HomeCardDefinition> definitions,
  required Map<String, CardState> states,
  required int maxCards,
  required DateTime now,
}) {
  final dismissedToday = {
    for (final card in candidates)
      if (card.isQueue && _isDismissedToday(states[card.stateKey], now))
        card.stateKey,
  };
  final seen = dismissedToday.isEmpty
      ? states
      : {
          for (final entry in states.entries)
            if (!dismissedToday.contains(entry.key)) entry.key: entry.value,
        };
  final kept = [
    for (final card in candidates)
      if (definitions.containsKey(card.type) &&
          _isShown(card, seen, now) &&
          (dismissedToday.isEmpty ||
              !card.isQueue ||
              _isToday(states[card.stateKey]?.lastShownAt, now)))
        card,
  ]..sort((a, b) {
      final byPriority = definitions[a.type]!.priority.compareTo(
            definitions[b.type]!.priority,
          );
      if (byPriority != 0) {
        return byPriority;
      }
      final aEvent = a.eventAt;
      final bEvent = b.eventAt;
      final byEvent = a.isQueue && b.isQueue && aEvent != null && bEvent != null
          ? aEvent.compareTo(bEvent)
          : _compareEvents(aEvent, bEvent, now);
      return byEvent != 0 ? byEvent : a.stateKey.compareTo(b.stateKey);
    });
  return [
    for (final card in kept.take(max(0, maxCards)))
      if (!dismissedToday.contains(card.stateKey)) card,
  ];
}

bool _isDismissedToday(CardState? state, DateTime now) {
  return _isToday(state?.dismissedAt, now);
}

bool _isToday(DateTime? date, DateTime now) {
  final local = date?.toLocal();
  final today = now.toLocal();
  return local != null &&
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
}

bool _isShown(
  HomeCardCandidate card,
  Map<String, CardState> states,
  DateTime now,
) {
  final state = states[card.stateKey];
  if (state == null) {
    return true;
  }
  if (card.dismissable && state.isHidden(now)) {
    return false;
  }
  final maxShows = card.maxShows;
  return maxShows == null || state.shownCount < maxShows;
}

int _compareEvents(DateTime? a, DateTime? b, DateTime now) {
  if (a == null || b == null) {
    return a == b ? 0 : (a == null ? 1 : -1);
  }
  return a.difference(now).abs().compareTo(b.difference(now).abs());
}
