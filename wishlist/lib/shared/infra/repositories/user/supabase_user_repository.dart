import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/non_null_extensions/go_true_client_non_null_getter_user_extension.dart';
import 'package:wishlist/shared/infra/repositories/user/user_repository.dart';
import 'package:wishlist/shared/infra/utils/execute_safely.dart';
import 'package:wishlist/shared/infra/utils/postgrest_user_message_key.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/profile.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository(this._client);
  final SupabaseClient _client;

  @override
  String? getCurrentUserEmail() {
    return _client.auth.currentUser?.email;
  }

  @override
  String getCurrentUserId() {
    return _client.auth.currentUserNonNull.id;
  }

  void _handleDuplicateProfileError(Object error) {
    if (error is PostgrestException) {
      throw AppException(
        statusCode: 409,
        message: 'User profile already exists',
        userMessageKey: userMessageKeyForPostgrestException(error),
      );
    }
  }

  @override
  Future<void> createUserProfile(Profile profile) async {
    return executeSafely(
      () async {
        await _client.from('profiles').insert(profile.toJson());
        await _client.auth.refreshSession();
      },
      errorMessage: 'Failed to create user profile',
      customErrorHandler: _handleDuplicateProfileError,
    );
  }

  @override
  Future<void> updateUserProfile(Profile profile) async {
    return executeSafely(
      () async {
        await _client
            .from('profiles')
            .update(profile.toJson())
            .eq('id', profile.id);
      },
      errorMessage: 'Failed to update user profile',
      customErrorHandler: _handleDuplicateProfileError,
    );
  }

  @override
  Future<IList<AppUser>> searchUsersByEmailOrPseudo(String query) async {
    return executeSafely(
      () async {
        final response = await _client.rpc<List<dynamic>>(
          'search_users',
          params: {'p_query': query},
        );

        return response
            .cast<Map<String, dynamic>>()
            .map(AppUser.fromJson)
            .toIList();
      },
      errorMessage: 'Failed to search user by email or pseudo',
    );
  }

  @override
  Future<AppUser> getAppUserById(String userId) async {
    return executeSafely(
      () async {
        final response = await _client
            .from('users_profiles')
            .select('id, user, profile')
            .eq('id', userId)
            .single();

        return AppUser.fromJson(response);
      },
      errorMessage: 'Failed to get user by id',
    );
  }

  @override
  Future<Birthday?> getCurrentUserBirthday() async {
    return executeSafely(
      () async {
        final response = await _client
            .from('profile_birthdays')
            .select('month, day')
            .eq('profile_id', getCurrentUserId())
            .maybeSingle();

        return response == null ? null : Birthday.tryFromJson(response);
      },
      errorMessage: 'Failed to get current user birthday',
    );
  }

  @override
  Future<Map<String, Birthday>> getVisibleBirthdays(
    ISet<String> friendIds,
  ) async {
    if (friendIds.isEmpty) {
      return const {};
    }
    return executeSafely(
      () async {
        // Filtered on the client: the RLS policy calls a SECURITY DEFINER
        // function per row, so an unfiltered select would scan the whole
        // table (cost by number of users, not of friends).
        final rows = await _client
            .from('profile_birthdays')
            .select('profile_id, month, day')
            .inFilter('profile_id', friendIds.toList());

        // One malformed row must not hide the other birthdays.
        final birthdays = <String, Birthday>{};
        for (final row in rows) {
          final profileId = row['profile_id'];
          final birthday = Birthday.tryFromJson(row);
          if (profileId is String && birthday != null) {
            birthdays[profileId] = birthday;
          } else {
            debugPrint('[Wishy birthdays] skipped a malformed row: $row');
          }
        }
        return birthdays;
      },
      errorMessage: 'Failed to get visible birthdays',
    );
  }

  @override
  Future<void> upsertCurrentUserBirthday(Birthday birthday) async {
    return executeSafely(
      () async {
        await _client.from('profile_birthdays').upsert({
          'profile_id': getCurrentUserId(),
          ...birthday.toJson(),
        });
      },
      errorMessage: 'Failed to save current user birthday',
    );
  }

  @override
  Future<void> deleteCurrentUserBirthday() async {
    return executeSafely(
      () async {
        await _client
            .from('profile_birthdays')
            .delete()
            .eq('profile_id', getCurrentUserId());
      },
      errorMessage: 'Failed to delete current user birthday',
    );
  }
}
