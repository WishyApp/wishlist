import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
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

/// How long the user can undo a swipe: the duration of the snack-bar. The
/// commit comes from the snack-bar closing (`commit`).
const homeCardUndoDuration = Duration(seconds: 4);

/// Safety net if the snack-bar never tells it closed: a bit after it should
/// have.
const homeCardCommitFallback = Duration(seconds: 5);

const _defaultLaterDays = 1;

/// Days a card swiped with "Later" is postponed, from the `home_stack` row, at
/// least one: "later" is never today.
int laterDaysOf(Map<String, HomeCardDefinition>? definitions) {
  final days =
      definitions?['home_stack']?.intParam('later_days', _defaultLaterDays) ??
          _defaultLaterDays;
  return max(_defaultLaterDays, days);
}

/// The cards the user swiped away. Its state is the set of card keys to take
/// off the screen: the ones waiting to be sent, and the ones sent during the
/// life of the notifier (the stack of cards does not reload at once).
///
/// A swipe is optimistic and sent late: the card goes at once, and the request
/// is made when the snack-bar closes (`commit`), unless `undo` came first. What
/// is still waiting is sent at once when the app goes to the background or the
/// notifier is disposed (the user left the screen); a timer sends it if the
/// snack-bar never reports. Whatever the cause, the snack-bar is then closed
/// so that no "Undo" is offered for what was sent.
final homeCardActionsProvider =
    NotifierProvider.autoDispose<HomeCardActions, Set<String>>(
  HomeCardActions.new,
);

class HomeCardActions extends AutoDisposeNotifier<Set<String>> {
  late CardStateRepository _cardStates;
  late BookedWishRemovalRepository _removals;
  final _waiting = <String, _Swipe>{};
  final _closers = <String, VoidCallback>{};
  final _shown = <String>{};
  var _disposed = false;

  @override
  Set<String> build() {
    _cardStates = ref.watch(cardStateRepositoryProvider);
    _removals = ref.watch(bookedWishRemovalRepositoryProvider);
    _disposed = false;
    // A process killed in the background never gets to the timer: send as soon
    // as the app stops being in front.
    final lifecycle = AppLifecycleListener(
      onInactive: _flush,
      onHide: _flush,
      onPause: _flush,
    );
    ref.onDispose(() {
      _disposed = true;
      lifecycle.dispose();
      _flush();
    });
    return const {};
  }

  /// Days of the postponement of "Later".
  int get laterDays =>
      laterDaysOf(ref.read(homeCardDefinitionsProvider).valueOrNull);

  /// Takes [card] off the screen and sends it later, see the class comment.
  ///
  /// With [autoCommit] false (screen reader users, whose snack-bar does not
  /// close by itself) no timer is started: only `commit`, the lifecycle or
  /// the end of the screen send it.
  void swipe(
    HomeCardCandidate card,
    HomeCardSwipe swipe, {
    bool autoCommit = true,
  }) {
    final key = card.stateKey;
    // Already off the screen, waiting or sent: a second swipe changes nothing
    if (_disposed || state.contains(key)) {
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
    if (autoCommit) {
      pending.timer = Timer(homeCardCommitFallback, () => _commit(key));
    }
    _waiting[key] = pending;
    state = {...state, key};
  }

  /// Takes [card] off the screen and hides it for good at once: no snack-bar,
  /// nothing to undo (the card was acted on, "Découvrir" for the recap).
  void dismissNow(HomeCardCandidate card) {
    final key = card.stateKey;
    if (_disposed || state.contains(key)) {
      return;
    }
    state = {...state, key};
    unawaited(_sendAndReload(_Swipe(card, null)));
  }

  /// Registers how to close the snack-bar of [stateKey]; called when the card
  /// is committed by anything but the snack-bar itself. At once if it already
  /// was.
  void attachCloser(String stateKey, VoidCallback close) {
    if (_disposed) {
      close();
    } else if (_waiting.containsKey(stateKey)) {
      _closers[stateKey] = close;
    } else if (state.contains(stateKey)) {
      close();
    }
  }

  /// The snack-bar of [stateKey] closed without "Undo": sends the card.
  void commit(String stateKey) {
    _closers.remove(stateKey);
    _commit(stateKey);
  }

  void _commit(String stateKey) {
    final swipe = _waiting.remove(stateKey);
    if (swipe == null) {
      return;
    }
    swipe.timer?.cancel();
    _closers.remove(stateKey)?.call();
    unawaited(_sendAndReload(swipe));
  }

  /// Sends everything that is waiting, the cards stay hidden.
  void _flush() {
    _waiting.keys.toList().forEach(_commit);
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
    _closers.remove(stateKey);
    swipe.timer?.cancel();
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
  Timer? timer;
}
