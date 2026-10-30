import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the stale wishlist cards did on one local day, on this device.
@immutable
class StaleCardsDay {
  const StaleCardsDay({this.shownKeys = const {}, this.dismissed = false});

  /// State keys of the stale cards that were in the stack that day.
  final Set<String> shownKeys;

  /// The user hid or postponed a stale card that day.
  final bool dismissed;
}

/// The stale cards of the day, kept on the device (not on the server: it must
/// be updated at the moment of the swipe, whatever the network does, and
/// follow the clock of the phone). One state per user, for the latest local
/// day seen: a new day forgets everything, a call about an earlier day (a
/// build that started before midnight) is ignored. Per device: another device
/// may show another stale card the same day.
///
/// The memory is the truth, the preferences only carry it across launches.
class StaleCardsDayStore {
  /// [prefs] gives the preferences; null (tests) keeps everything in memory.
  StaleCardsDayStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs;

  static const _key = 'stale_cards_day';

  final Future<SharedPreferences> Function()? _prefs;
  Future<void>? _loading;

  /// The latest local day seen, as `yyyymmdd`.
  int? _date;
  final _days = <String, ({Set<String> shown, bool dismissed})>{};

  /// Reads the saved state once; to await before the first `dayOf`.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = (await _prefs?.call())?.getString(_key);
      if (raw == null || _date != null) {
        return;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final date = json['date'] as int;
      final days = {
        for (final entry in (json['users'] as Map<String, dynamic>).entries)
          entry.key: (
            shown: ((entry.value as Map<String, dynamic>)['shown'] as List)
                .cast<String>()
                .toSet(),
            dismissed:
                (entry.value as Map<String, dynamic>)['dismissed'] as bool,
          ),
      };
      // Only when everything was read
      _date = date;
      _days.addAll(days);
    } on Object catch (e) {
      debugPrint('[Wishy stale cards] could not read the day: $e');
    }
  }

  /// The state of [userId] on the local day of [now]; empty, and never
  /// blocking, for a day before the latest one seen.
  StaleCardsDay dayOf(String userId, DateTime now) {
    if (!_enter(now)) {
      return const StaleCardsDay();
    }
    final day = _days[userId];
    return day == null
        ? const StaleCardsDay()
        : StaleCardsDay(shownKeys: {...day.shown}, dismissed: day.dismissed);
  }

  /// The user hid or postponed a stale card: effective at once.
  /// [stackKeys] are the stale cards of the stack the user swiped in, kept as
  /// shown that day: the stack on screen may be older than the day of [now].
  void markDismissed(
    String userId,
    DateTime now, {
    Iterable<String> stackKeys = const [],
  }) {
    if (!_enter(now)) {
      return;
    }
    final day = _days[userId];
    _days[userId] = (shown: {...?day?.shown, ...stackKeys}, dismissed: true);
    unawaited(_save());
  }

  /// [keys] are in the stack of the day.
  void addShown(String userId, DateTime now, Iterable<String> keys) {
    if (!_enter(now)) {
      return;
    }
    final day = _days[userId];
    final shown = {...?day?.shown, ...keys};
    if (day == null || shown.length != day.shown.length) {
      _days[userId] = (shown: shown, dismissed: day?.dismissed ?? false);
      unawaited(_save());
    }
  }

  /// False when [now] is before the latest day seen: nothing may change.
  bool _enter(DateTime now) {
    final local = now.toLocal();
    final date = local.year * 10000 + local.month * 100 + local.day;
    final current = _date;
    if (current != null && date < current) {
      return false;
    }
    if (current != date) {
      _date = date;
      _days.clear();
    }
    return true;
  }

  Future<void> _save() async {
    try {
      await load();
      await (await _prefs?.call())?.setString(
        _key,
        jsonEncode({
          'date': _date,
          'users': {
            for (final entry in _days.entries)
              entry.key: {
                'shown': entry.value.shown.toList(),
                'dismissed': entry.value.dismissed,
              },
          },
        }),
      );
    } on Object catch (e) {
      debugPrint('[Wishy stale cards] could not save the day: $e');
    }
  }
}

final staleCardsDayStoreProvider = Provider<StaleCardsDayStore>(
  (ref) => StaleCardsDayStore(prefs: SharedPreferences.getInstance),
);
