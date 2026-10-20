import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/app_user.dart';

final currentUserProfileProvider =
    FutureProvider.autoDispose<AppUser>((ref) async {
  final userService = ref.watch(userServiceProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) {
    // Signed out: the screens using it are going away, keep it loading.
    return Completer<AppUser>().future;
  }

  return userService.getAppUserById(currentUserId);
});
