import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/birthday.dart';

/// Birthdays tagged with the id of the user they were loaded for, so that a
/// value kept by Riverpod across a user switch is never taken for the new
/// user's.
typedef VisibleBirthdays = ({
  String? userId,
  Map<String, Birthday> birthdays,
});

/// Birthdays of the current user's friends, by profile id.
///
/// Birthdays are a bonus: any failed load is logged and gives an empty map
/// instead of an error.
///
/// Waits for the list of friends, and does not query anything without
/// friends. Rebuilt on a user switch, and when the set of friends changes (a
/// friendship accepted or removed). Not a stream: a friend changing their
/// birthday is seen on the next refresh.
final visibleBirthdaysProvider =
    FutureProvider.autoDispose<VisibleBirthdays>((ref) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  final userService = ref.watch(userServiceProvider);

  if (currentUserId == null) {
    return (userId: null, birthdays: const <String, Birthday>{});
  }

  try {
    // Only the ids matter: a profile change must not reload the birthdays.
    // An ISet is compared by value, whatever the order.
    final friendIds = await ref.watch(
      friendshipsRealtimeProvider.selectAsync(
        (data) => data.friends.map((f) => f.user.id).toISet(),
      ),
    );
    return (
      userId: currentUserId,
      birthdays: await userService.getVisibleBirthdays(friendIds),
    );
  } catch (e) {
    debugPrint('[Wishy birthdays] load failed, showing none: $e');
    return (userId: currentUserId, birthdays: const <String, Birthday>{});
  }
});

/// Birthday of the profile if the current user may see it.
final friendBirthdayProvider = Provider.autoDispose.family<Birthday?, String>((
  ref,
  profileId,
) {
  final currentUserId = ref.watch(currentUserIdProvider);
  return ref.watch(
    visibleBirthdaysProvider.select((value) {
      // Riverpod keeps the previous value while reloading, and after an
      // error: it may be the one of the previous user.
      final data = value.valueOrNull;
      if (data == null || data.userId != currentUserId) {
        return null;
      }
      return data.birthdays[profileId];
    }),
  );
});
