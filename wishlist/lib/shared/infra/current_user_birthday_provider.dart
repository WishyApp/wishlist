import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/birthday.dart';

/// Birthday of the current user, null if they did not set one.
///
/// Not a stream: only the current user changes it, and the screen that does
/// invalidates this provider after saving.
final currentUserBirthdayProvider =
    FutureProvider.autoDispose<Birthday?>((ref) async {
  final userService = ref.watch(userServiceProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) {
    // Signed out: the screens using it are going away, keep it loading.
    return Completer<Birthday?>().future;
  }

  return userService.getCurrentUserBirthday();
});
