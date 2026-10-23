import 'package:intl/intl.dart';
import 'package:wishlist/l10n/l10n.dart';

/// Formate [date] par rapport à [now], en jours calendaires :
/// - « Aujourd'hui », « Hier », « Il y a 3 jours » ;
/// - « Il y a 2 semaines » jusqu'à 4 semaines, et toujours dans le mois en
///   cours ;
/// - au-delà, le mois (« Septembre »), avec l'année si elle diffère
///   (« Sept. 2025 »).
String formatRelativeDate(
  AppLocalizations l10n,
  DateTime date, {
  required DateTime now,
  required String locale,
}) {
  final localDate = date.toLocal();
  final localNow = now.toLocal();
  // Dates en UTC pour que la différence ne dépende pas des changements
  // d'heure
  final days = DateTime.utc(localNow.year, localNow.month, localNow.day)
      .difference(
        DateTime.utc(localDate.year, localDate.month, localDate.day),
      )
      .inDays;

  if (days <= 0) {
    return l10n.relativeDateToday;
  }
  if (days == 1) {
    return l10n.relativeDateYesterday;
  }
  if (days < 7) {
    return l10n.relativeDateDaysAgo(days);
  }
  // Weeks within the current month whatever the count (a month name would
  // read as "this month"), and up to 4 weeks before it
  final isSameMonth =
      localDate.year == localNow.year && localDate.month == localNow.month;
  if (days < 30 || isSameMonth) {
    return l10n.relativeDateWeeksAgo(days ~/ 7);
  }

  final month = localDate.year == localNow.year
      ? DateFormat.MMMM(locale).format(localDate)
      : DateFormat.yMMM(locale).format(localDate);
  return _capitalize(month);
}

String _capitalize(String input) =>
    input.isEmpty ? input : input[0].toUpperCase() + input.substring(1);
