import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/profile.dart';

abstract class UserRepository {
  /// Email of the current user.
  ///
  /// Null means "nobody is signed in (e.g. right after a sign-out, before the
  /// redirect) OR the account has no email": callers must not treat null as
  /// "signed out".
  String? getCurrentUserEmail();
  String getCurrentUserId();
  Future<void> createUserProfile(Profile profile);
  Future<void> updateUserProfile(Profile profile);
  Future<IList<AppUser>> searchUsersByEmailOrPseudo(String query);
  Future<AppUser> getAppUserById(String userId);
}
