import 'package:wishlist/shared/models/home_card_definition.dart';

abstract class HomeCardRepository {
  /// Rows of `home_cards` the user can read (enabled, editorial ones inside
  /// their window), most urgent first. Includes the `home_stack` settings
  /// row: the home screen splits it from the cards.
  Future<List<HomeCardDefinition>> getActiveCards();
}
