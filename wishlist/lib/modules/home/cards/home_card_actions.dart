import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/home/cards/card_builders.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/modules/home/cards/stale_cards_day_store.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
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
/// off the screen: the ones waiting to be sent, and the ones sent until a
/// reload no longer holds them (`release`: the stack of cards does not reload
/// at once, and a card postponed comes back on its day).
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

/// A send that failed (offline): the card is back, the screen tells the user.
/// A new object each time, so that two failures in a row both notify.
final homeCardSendFailureProvider =
    StateProvider.autoDispose<HomeCardSendFailure?>((ref) => null);

class HomeCardSendFailure {
  HomeCardSendFailure(this.error);

  final Object error;
}

class HomeCardActions extends AutoDisposeNotifier<Set<String>> {
  late CardStateRepository _cardStates;
  late BookedWishRemovalRepository _removals;
  final _waiting = <String, _Swipe>{};
  final _closers = <String, VoidCallback>{};
  final _shown = <String>{};
  final _sent = <String>{};
  var _disposed = false;

  @override
  Set<String> build() {
    _cardStates = ref.watch(cardStateRepositoryProvider);
    _removals = ref.watch(bookedWishRemovalRepositoryProvider);
    _disposed = false;
    // A process killed in the background never gets to the timer: send as soon
    // as the app is hidden. Not on inactive: the control center or a call
    // banner is not leaving, and the user could still want to undo.
    final lifecycle = AppLifecycleListener(
      onHide: _flush,
      onPause: _flush,
      // Reached from paused: a swipe made after the pause is still sent
      onDetach: _flush,
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
  /// False when it was already off the screen (waiting or sent): nothing
  /// changed, so the caller has nothing to offer to undo.
  ///
  /// With [autoCommit] false (screen reader users, whose snack-bar does not
  /// close by itself) no timer is started: only `commit`, the lifecycle or
  /// the end of the screen send it.
  bool swipe(
    HomeCardCandidate card,
    HomeCardSwipe swipe, {
    bool autoCommit = true,
  }) {
    final key = card.stateKey;
    // Already off the screen, waiting or sent: a second swipe changes nothing
    if (_disposed || state.contains(key)) {
      return false;
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
    _markStaleDismissed(card, now);
    final pending = _Swipe(card, until);
    if (autoCommit) {
      pending.timer = Timer(homeCardCommitFallback, () => _commit(key));
    }
    _waiting[key] = pending;
    state = {...state, key};
    return true;
  }

  /// A reload holds [loadedKeys]: the cards sent and no longer among them are
  /// no longer to filter out, so that they show again when they come back (the
  /// next day, at the next reminder step).
  void release(Set<String> loadedKeys) {
    final gone = _sent.difference(loadedKeys);
    if (_disposed || gone.isEmpty) {
      return;
    }
    _sent.removeAll(gone);
    state = {...state}..removeAll(gone);
  }

  /// Takes [card] off the screen and hides it for good at once: no snack-bar,
  /// nothing to undo (the card was acted on, "Découvrir" for the recap).
  void dismissNow(HomeCardCandidate card) {
    final key = card.stateKey;
    if (_disposed || state.contains(key)) {
      return;
    }
    _markStaleDismissed(card, ref.read(clockProvider)());
    state = {...state, key};
    unawaited(_sendAndReload(_Swipe(card, null)));
  }

  /// A stale card acted on blocks the other stale lists until tomorrow, from
  /// the moment of the swipe: the request is sent later and an undo does not
  /// lift the block (see `StaleCardsDayStore`).
  void _markStaleDismissed(HomeCardCandidate card, DateTime now) {
    if (!card.isQueue) {
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      ref.read(staleCardsDayStoreProvider).markDismissed(userId, now);
    }
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
    final error = await _send(swipe);
    if (_disposed) {
      return;
    }
    final key = swipe.card.stateKey;
    if (error != null) {
      // Never closed: the card is back, and the user is told
      state = {...state}..remove(key);
      ref.read(homeCardSendFailureProvider.notifier).state =
          HomeCardSendFailure(error);
      return;
    }
    _sent.add(key);
    // An alert is closed on its own table, whose stream reloads the cards.
    if (swipe.card.content is! BookedWishRemoved) {
      // The next card may take its place now that this one is gone.
      ref.invalidate(homeCardsProvider);
    }
  }

  /// The error, null when sent.
  Future<Object?> _send(_Swipe swipe) async {
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
      return null;
    } catch (e) {
      debugPrint(
        '[Wishy home cards] could not send ${swipe.card.stateKey}: $e',
      );
      return e;
    }
  }
}

class _Swipe {
  _Swipe(this.card, this.until);

  final HomeCardCandidate card;
  final DateTime? until;
  Timer? timer;
}
