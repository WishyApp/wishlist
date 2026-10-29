import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';

abstract class UserCompletedWishRepository {
  /// Marque un wish comme complété pour l'utilisateur courant, reçu le jour
  /// de [completedAt]. S'il l'était déjà, la quantité s'ajoute et le jour le
  /// plus récent des deux est gardé.
  Future<void> markAsCompleted({
    required String userId,
    required int wishId,
    required int fromWishlistId,
    required int quantity,
    required DateTime completedAt,
  });

  /// Met à jour la quantité d'un wish complété.
  Future<void> updateCompletedWishQuantity({
    required String userId,
    required int wishId,
    required int newQuantity,
  });

  /// Change le jour où un wish complété a été reçu.
  Future<void> updateCompletionDate({
    required String userId,
    required int wishId,
    required DateTime completedAt,
  });

  /// Retire un wish de l'état complété.
  Future<void> unmarkAsCompleted({
    required String userId,
    required int wishId,
  });

  /// Déplace un wish depuis sa wishlist archivée et retire sa complétion.
  Future<void> restoreCompletedWish({
    required int wishId,
    required int targetWishlistId,
  });

  /// Récupère tous les wishs complétés d'un utilisateur avec leurs détails.
  Future<IList<CompletedWishWithDetails>> getCompletedWishesByUser(
    String userId,
  );

  /// Count and latest day of the wishes a user received, without their
  /// details. Counts the same rows as [getCompletedWishesByUser].
  Future<ReceivedWishesSummary> getReceivedWishesSummary(String userId);
}
