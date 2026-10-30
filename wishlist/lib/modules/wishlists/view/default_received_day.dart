import 'package:intl/intl.dart';

final _receivedOnFormat = DateFormat('yyyy-MM-dd');

/// The party day the wishlist was opened for (`received-on` query parameter of
/// the WishlistRoute), as a local day. Null when absent or not a plain
/// `yyyy-MM-dd` day, so a mangled link keeps the usual behaviour.
DateTime? parseReceivedOn(String? value) {
  if (value == null) {
    return null;
  }
  try {
    return _receivedOnFormat.parseStrict(value);
  } on FormatException {
    return null;
  }
}

/// The `received-on` query value of [day] (`yyyy-MM-dd`).
String formatReceivedOn(DateTime day) => _receivedOnFormat.format(day);
