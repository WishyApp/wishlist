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
/// follow the clock of the phone). A card of another user or another local day
/// is forgotten. Per device: another device may show another stale card the
/// same day.
///
/// The memory is the truth, the preferences only carry it across launches.
class StaleCardsDayStore {
  /// [prefs] gives the preferences; null (tests) keeps everything in memory.
  StaleCardsDayStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs;

  static const _key = 'stale_cards_day';

  final Future<SharedPreferences> Function()? _prefs;
  Future<void>? _loading;
  String? _userId;
  String? _date;
  final _shown = <String>{};
  var _dismissed = false;

  /// Reads the saved state once; to await before the first `dayOf`.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = (await _prefs?.call())?.getString(_key);
      if (raw == null || _date != null) {
        return;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _userId = json['userId'] as String?;
      _date = json['date'] as String?;
      _shown.addAll((json['shown'] as List).cast<String>());
      _dismissed = json['dismissed'] as bool;
    } on Object catch (e) {
      debugPrint('[Wishy stale cards] could not read the day: $e');
    }
  }

  /// The state of [userId] on the local day of [now].
  StaleCardsDay dayOf(String userId, DateTime now) {
    _enter(userId, now);
    return StaleCardsDay(shownKeys: {..._shown}, dismissed: _dismissed);
  }

  /// The user hid or postponed a stale card: effective at once.
  void markDismissed(String userId, DateTime now) {
    _enter(userId, now);
    _dismissed = true;
    unawaited(_save());
  }

  /// [keys] are in the stack of the day.
  void addShown(String userId, DateTime now, Iterable<String> keys) {
    _enter(userId, now);
    final before = _shown.length;
    _shown.addAll(keys);
    if (_shown.length != before) {
      unawaited(_save());
    }
  }

  void _enter(String userId, DateTime now) {
    final local = now.toLocal();
    final date = '${local.year}-${local.month}-${local.day}';
    if (_userId != userId || _date != date) {
      _userId = userId;
      _date = date;
      _shown.clear();
      _dismissed = false;
    }
  }

  Future<void> _save() async {
    try {
      await load();
      await (await _prefs?.call())?.setString(
        _key,
        jsonEncode({
          'userId': _userId,
          'date': _date,
          'shown': _shown.toList(),
          'dismissed': _dismissed,
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
