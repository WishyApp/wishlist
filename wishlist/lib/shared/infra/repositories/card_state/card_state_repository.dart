import 'package:wishlist/shared/models/card_state.dart';

abstract class CardStateRepository {
  /// States of the current user for [cardKeys] only, by card key. Rows
  /// accumulate for good while a response is capped by the server, so the
  /// caller asks for the keys it is about to display. No request is made for
  /// an empty list.
  Future<Map<String, CardState>> getStates(Iterable<String> cardKeys);

  /// The card was shown to the current user.
  Future<void> recordShown(String cardKey);

  /// The current user dismissed the card. With [snoozeUntil] it comes back
  /// after that date, without it never.
  Future<void> dismiss(String cardKey, {DateTime? snoozeUntil});
}
