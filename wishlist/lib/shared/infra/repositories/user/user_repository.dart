import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';
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

  /// Birthday of the current user, null if they did not set one.
  Future<Birthday?> getCurrentUserBirthday();

  /// Birthdays of [friendIds] the current user may see (RLS only returns the
  /// ones of accepted friends), by profile id. No request for an empty set.
  Future<Map<String, Birthday>> getVisibleBirthdays(ISet<String> friendIds);
  Future<void> upsertCurrentUserBirthday(Birthday birthday);
  Future<void> deleteCurrentUserBirthday();
}
