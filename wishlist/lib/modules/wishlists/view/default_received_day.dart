/// The party day the wishlist was opened for (`received-on` query parameter of
/// the WishlistRoute), as a local day. Null when absent or not a plain
/// `yyyy-MM-dd` day, so a mangled link keeps the usual behaviour.
DateTime? parseReceivedOn(String? value) {
  if (value == null) {
    return null;
  }
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime rolls 2026-13-45 over to another day: reject it
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// The `received-on` query value of [day] (`yyyy-MM-dd`).
String formatReceivedOn(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final dayOfMonth = day.day.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-$month-$dayOfMonth';
}

/// The day to propose as received date when marking wishes received: the
/// [receivedOn] party day, kept within the creation day of the latest of
/// [wishCreatedAts] and today ([now]). Null without [receivedOn], where the
/// dialog starts on today as usual.
DateTime? defaultReceivedDay({
  required DateTime? receivedOn,
  required DateTime now,
  required Iterable<DateTime> wishCreatedAts,
}) {
  if (receivedOn == null) {
    return null;
  }
  DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  var day = dayOf(receivedOn);
  for (final createdAt in wishCreatedAts) {
    final created = dayOf(createdAt.toLocal());
    if (created.isAfter(day)) {
      day = created;
    }
  }
  final today = dayOf(now);
  return day.isAfter(today) ? today : day;
}
