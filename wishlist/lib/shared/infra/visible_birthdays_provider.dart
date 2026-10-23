import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/birthday.dart';

/// Birthdays the current user may see, by profile id (RLS only returns the
/// ones of accepted friends, and their own).
///
/// Birthdays are a bonus: a failed load gives an empty map (logged) instead of
/// an error, it must not break the screens showing them.
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
  } catch (e) {
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
    visibleBirthdaysProvider.select((value) => value.valueOrNull?[profileId]),
  );
});
