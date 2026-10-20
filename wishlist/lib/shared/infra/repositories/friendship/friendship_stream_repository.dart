import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';

/// Données de tous les types de friendships pour l'utilisateur courant
@immutable
class FriendshipIds {
  const FriendshipIds({
    required this.friendsIds,
    required this.pendingIds,
    required this.requestedIds,
  });

  final ISet<String> friendsIds;
  final ISet<String> pendingIds;
  final ISet<String> requestedIds;

  @override
  bool operator ==(Object other) =>
      other is FriendshipIds &&
      other.friendsIds == friendsIds &&
      other.pendingIds == pendingIds &&
      other.requestedIds == requestedIds;

  @override
  int get hashCode => Object.hash(friendsIds, pendingIds, requestedIds);
}

/// Interface pour écouter les changements en temps réel sur les friendships
abstract class FriendshipStreamRepository {
  /// 🎯 Écoute TOUS les changements de friendships de l'utilisateur courant
  ///
  /// Retourne un stream qui émet FriendshipIds à chaque changement
  /// C'est la méthode recommandée pour éviter les race conditions
  Stream<FriendshipIds> watchCurrentUserAllFriendships();

  /// Écoute tous les changements sur les IDs des amis d'un utilisateur
  ///
  /// Émet un nouveau set à chaque changement (ajout/suppression d'ami)
  Stream<ISet<String>> watchFriendsIds(String userId);

  /// Écoute les changements sur les demandes d'amitié en attente (reçues)
  Stream<ISet<String>> watchCurrentUserPendingFriendsIds();

  /// Écoute les changements sur les demandes d'amitié envoyées
  Stream<ISet<String>> watchCurrentUserRequestedFriendsIds();

  /// Ferme tous les streams et libère les ressources
  Future<void> dispose();
}
