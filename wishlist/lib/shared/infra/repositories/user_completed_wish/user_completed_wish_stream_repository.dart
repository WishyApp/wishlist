import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';

/// Repository abstrait pour les opérations Realtime sur user_completed_wishs.
abstract class UserCompletedWishStreamRepository {
  /// Écoute tous les wishs complétés d'un utilisateur avec leurs détails.
  ///
  /// Émet une nouvelle liste à chaque INSERT/DELETE sur user_completed_wishs,
  /// ou quand les données liées (wishs, wishlists, profiles) changent.
  Stream<IList<CompletedWishWithDetails>> watchCompletedWishesByUser(
    String userId,
  );

  /// Écoute le nombre et le dernier jour des wishs reçus d'un utilisateur.
  ///
  /// Plus léger que [watchCompletedWishesByUser] : le channel n'écoute que
  /// user_completed_wishs, filtré sur l'utilisateur, pas les wishs, wishlists
  /// et profils de tout le monde.
  Stream<ReceivedWishesSummary> watchReceivedWishesSummary(String userId);

  /// Nettoie les ressources (channels Realtime).
  void dispose();
}
