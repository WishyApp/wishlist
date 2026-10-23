import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/birthday.dart';

/// Birthdays the current user may see, by profile id (RLS only returns the
/// ones of accepted friends, and their own).
///
/// Birthdays are a bonus: a failed query (`AppException`, what the repository
/// throws) gives an empty map, logged, instead of an error. Any other error
/// propagates as an `AsyncError`: the consumers only read `valueOrNull`, so
/// the screens stay up anyway.
///
/// Rebuilt on a user switch, and when the set of friends changes (a friendship
/// accepted or removed). Not a stream: a friend changing their birthday is
/// seen on the next refresh.
final visibleBirthdaysProvider =
    FutureProvider.autoDispose<Map<String, Birthday>>((ref) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  final userService = ref.watch(userServiceProvider);
  // Only the ids matter: a profile change must not reload the birthdays. A
  // string, as a collection would never be equal to the previous one.
  ref.watch(
    friendshipsRealtimeProvider.select(
      (data) => (data.valueOrNull?.friends.map((f) => f.user.id).toList()
            ?..sort())
          ?.join(','),
    ),
  );

  if (currentUserId == null) {
    return const {};
  }

  try {
    return await userService.getVisibleBirthdays();
  } on AppException catch (e) {
    debugPrint('[Wishy birthdays] load failed, showing none: $e');
    return const {};
  }
});

/// Birthday of the profile if the current user may see it.
final friendBirthdayProvider = Provider.autoDispose.family<Birthday?, String>((
  ref,
  profileId,
) {
  return ref.watch(
    visibleBirthdaysProvider.select((value) {
      // After a dependency change (user switch, friends changed) the previous
      // value is still there while reloading: it may be the one of the
      // previous user. Only a refresh (pull-to-refresh) keeps it.
      final isStale = value.isLoading && !value.isRefreshing;
      return isStale ? null : value.valueOrNull?[profileId];
    }),
  );
});
