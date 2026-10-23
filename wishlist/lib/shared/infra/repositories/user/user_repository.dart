import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/profile.dart';

abstract class UserRepository {
  /// Null quand plus personne n'est connecté (ex: juste après une
  /// déconnexion, avant la redirection).
  String? getCurrentUserEmail();
  String getCurrentUserId();
  Future<void> createUserProfile(Profile profile);
  Future<void> updateUserProfile(Profile profile);
  Future<IList<AppUser>> searchUsersByEmailOrPseudo(String query);
  Future<AppUser> getAppUserById(String userId);
}
