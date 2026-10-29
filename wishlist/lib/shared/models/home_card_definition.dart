import 'package:flutter/foundation.dart';

/// What a `home_cards` row is: a card computed by the app, a hand-written
/// editorial card, or the settings of the stack itself.
enum HomeCardKind { computed, editorial, settings }

/// One row of `home_cards`: how a home card type is tuned (computed), or a
/// one-off card with its own texts (editorial).
@immutable
class HomeCardDefinition {
  const HomeCardDefinition({
    required this.key,
    required this.kind,
    required this.priority,
    this.params = const {},
    this.eventAt,
    this.startsAt,
    this.endsAt,
    this.title,
    this.body,
    this.ctaLabel,
    this.ctaRoute,
    this.illustration,
  });

  /// Throws if a column is missing or has the wrong type.
  factory HomeCardDefinition.fromRow(Map<String, dynamic> row) {
    return HomeCardDefinition(
      key: row['key'] as String,
      kind: HomeCardKind.values.byName(row['kind'] as String),
      priority: row['priority'] as int,
      params: Map<String, dynamic>.from(row['params'] as Map? ?? const {}),
      eventAt: _parseDate(row['event_at']),
      startsAt: _parseDate(row['starts_at']),
      endsAt: _parseDate(row['ends_at']),
      title: _parseTexts(row['title']),
      body: _parseTexts(row['body']),
      ctaLabel: _parseTexts(row['cta_label']),
      ctaRoute: row['cta_route'] as String?,
      illustration: row['illustration'] as String?,
    );
  }

  final String key;
  final HomeCardKind kind;

  /// Smaller is more urgent.
  final int priority;

  /// Tuning of the card (thresholds, reminder steps), see the seeds of the
  /// `home_cards` migration.
  final Map<String, dynamic> params;

  /// Date of the occasion (editorial).
  final DateTime? eventAt;

  /// Display window (editorial).
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Texts by language code (editorial).
  final Map<String, String>? title;
  final Map<String, String>? body;
  final Map<String, String>? ctaLabel;

  /// Route from `routes.dart` opened by the call to action.
  final String? ctaRoute;

  /// Name of an SVG of `assets/svg/`, without extension.
  final String? illustration;

  /// The text in [languageCode], else in french, else null.
  String? localized(Map<String, String>? texts, String languageCode) {
    if (texts == null) {
      return null;
    }
    return texts[languageCode] ?? texts['fr'];
  }

  int intParam(String name, int fallback) {
    final value = params[name];
    return value is num ? value.toInt() : fallback;
  }

  /// Empty if the param is absent or not a list of numbers.
  List<int> intListParam(String name) {
    final value = params[name];
    if (value is! List || value.any((e) => e is! num)) {
      return const [];
    }
    return [for (final e in value) (e as num).toInt()];
  }

  /// Empty if the param is absent or not a list of strings.
  List<String> stringListParam(String name) {
    final value = params[name];
    if (value is! List || value.any((e) => e is! String)) {
      return const [];
    }
    return List<String>.from(value);
  }

  /// Start of the first reminder step after [dismissedAt]: `reminder_days`
  /// days before [eventAt], then the day itself. Null once none is left.
  /// Used as the snooze date of "Hide".
  DateTime? nextReminderAfter({
    required DateTime eventAt,
    required DateTime dismissedAt,
  }) {
    final steps = [
      for (final days in intListParam('reminder_days'))
        _dayStart(eventAt, -days),
      _dayStart(eventAt, 0),
    ]..sort();
    for (final step in steps) {
      if (step.isAfter(dismissedAt)) {
        return step;
      }
    }
    return null;
  }

  /// Whether [eventAt] is at most `highlight_days` days away (default 7) and
  /// not past. Computed cards (birthday, Christmas) work out their own date.
  bool isHighlighted({required DateTime eventAt, required DateTime now}) {
    final remaining = eventAt.difference(now);
    return !remaining.isNegative &&
        remaining <= Duration(days: intParam('highlight_days', 7));
  }

  static DateTime _dayStart(DateTime date, int dayOffset) {
    return date.isUtc
        ? DateTime.utc(date.year, date.month, date.day + dayOffset)
        : DateTime(date.year, date.month, date.day + dayOffset);
  }

  static DateTime? _parseDate(Object? value) {
    return value == null ? null : DateTime.parse(value as String).toUtc();
  }

  static Map<String, String>? _parseTexts(Object? value) {
    if (value == null) {
      return null;
    }
    return (value as Map).map((k, v) => MapEntry(k as String, v as String));
  }
}
