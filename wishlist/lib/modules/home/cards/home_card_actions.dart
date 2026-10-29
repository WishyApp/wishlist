import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/home/cards/card_builders.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository_provider.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

/// How a card is swiped away: "Hide" (left) or "Later" (right).
enum HomeCardSwipe { hide, later }

/// How long the user can undo a swipe: the duration of the snack-bar.
const homeCardUndoDuration = Duration(seconds: 4);

const _defaultLaterDays = 1;

/// Days a card swiped with "Later" is postponed, from the `home_stack` row.
int laterDaysOf(Map<String, HomeCardDefinition>? definitions) {
  return definitions?['home_stack']
          ?.intParam('later_days', _defaultLaterDays) ??
      _defaultLaterDays;
}

/// The cards the user swiped away. Its state is the set of card keys to take
/// off the screen: the ones waiting to be sent, and the ones sent during the
/// life of the notifier (the stack of cards does not reload at once).
///
/// A swipe is optimistic and sent late: the card goes at once, and the request
/// is made when [homeCardUndoDuration] is over, unless `undo` came first. What
/// is still waiting when the notifier is disposed (the user left the screen)
/// is sent then.
final homeCardActionsProvider =
    NotifierProvider.autoDispose<HomeCardActions, Set<String>>(
  HomeCardActions.new,
);

class HomeCardActions extends AutoDisposeNotifier<Set<String>> {
  late CardStateRepository _cardStates;
  late BookedWishRemovalRepository _removals;
  final _waiting = <String, _Swipe>{};
  final _shown = <String>{};
  var _disposed = false;

  @override
  Set<String> build() {
    _cardStates = ref.watch(cardStateRepositoryProvider);
    _removals = ref.watch(bookedWishRemovalRepositoryProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      final waiting = _waiting.values.toList();
      _waiting.clear();
      for (final swipe in waiting) {
        swipe.timer.cancel();
        unawaited(_send(swipe));
      }
    });
    return const {};
  }

  /// Days of the postponement of "Later".
  int get laterDays =>
      laterDaysOf(ref.read(homeCardDefinitionsProvider).valueOrNull);

  /// Takes [card] off the screen and sends it later, see the class comment.
  void swipe(HomeCardCandidate card, HomeCardSwipe swipe) {
    final key = card.stateKey;
    if (_disposed || _waiting.containsKey(key)) {
      return;
    }
    final now = ref.read(clockProvider)();
    final definitions = ref.read(homeCardDefinitionsProvider).valueOrNull;
    final until = switch (swipe) {
      HomeCardSwipe.hide => hideUntil(card, definitions ?? const {}, now),
      // Start of the local day, so that "tomorrow" is the same all day.
      HomeCardSwipe.later => DateTime(
          now.year,
          now.month,
          now.day + laterDaysOf(definitions),
        ),
    };
    final pending = _Swipe(card, until);
    pending.timer = Timer(homeCardUndoDuration, () {
      _waiting.remove(key);
      unawaited(_sendAndReload(pending));
    });
    _waiting[key] = pending;
    state = {...state, key};
  }

  /// Brings the card back and sends nothing, if it was not sent yet.
  void undo(String stateKey) {
    if (_disposed) {
      return;
    }
    final swipe = _waiting.remove(stateKey);
    if (swipe == null) {
      return;
    }
    swipe.timer.cancel();
    state = {...state}..remove(stateKey);
  }

  /// The card is in front of the user: records it once per card and per life
  /// of the notifier. Does not touch `onboarding:optional_window`, the start
  /// of the window of the optional onboarding steps: `homeCardsProvider`
  /// records it itself, when the step is the top card.
  void recordShown(String stateKey) {
    if (_disposed || !_shown.add(stateKey)) {
      return;
    }
    unawaited(_recordShown(stateKey));
  }

  Future<void> _recordShown(String stateKey) async {
    try {
      await _cardStates.recordShown(stateKey);
    } catch (e) {
      debugPrint('[Wishy home cards] could not record $stateKey: $e');
    }
  }

  Future<void> _sendAndReload(_Swipe swipe) async {
    await _send(swipe);
    if (!_disposed) {
      // The next card may take its place now that this one is gone.
      ref.invalidate(homeCardsProvider);
    }
  }

  Future<void> _send(_Swipe swipe) async {
    final content = swipe.card.content;
    try {
      if (content is BookedWishRemoved) {
        // An alert is closed on its own table, not through the card states.
        await _removals.dismiss(content.removal.id);
      } else {
        await _cardStates.dismiss(
          swipe.card.stateKey,
          snoozeUntil: swipe.until,
        );
      }
    } catch (e) {
      debugPrint(
        '[Wishy home cards] could not send ${swipe.card.stateKey}: $e',
      );
    }
  }
}

class _Swipe {
  _Swipe(this.card, this.until);

  final HomeCardCandidate card;
  final DateTime? until;
  late final Timer timer;
}
