import 'package:wishlist/shared/models/card_state.dart';

abstract class CardStateRepository {
  /// States of the current user, by card key.
  Future<Map<String, CardState>> getStates();

  /// The card was shown to the current user.
  Future<void> recordShown(String cardKey);

  /// The current user dismissed the card. With [snoozeUntil] it comes back
  /// after that date, without it never.
  Future<void> dismiss(String cardKey, {DateTime? snoozeUntil});
}
