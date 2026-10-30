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
/// With [queueKeys], the cards of a queue whose state key is not in it are
/// dropped: the queue may shrink, never gain a card (see `StaleCardsDay`).
List<HomeCardCandidate> selectHomeCards({
  required List<HomeCardCandidate> candidates,
  required Map<String, HomeCardDefinition> definitions,
  required Map<String, CardState> states,
  required int maxCards,
  required DateTime now,
  Set<String>? queueKeys,
}) {
  final kept = [
    for (final card in candidates)
      if (definitions.containsKey(card.type) &&
          _isShown(card, states, now) &&
          (queueKeys == null ||
              !card.isQueue ||
              queueKeys.contains(card.stateKey)))
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
  return kept.take(max(0, maxCards)).toList();
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
