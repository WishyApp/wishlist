import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/avatar_service.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';

class AvatarNotifier extends StateNotifier<AsyncValue<String?>> {
  AvatarNotifier(
    this._avatarService,
    this._userService, {
    required String? userId,
  }) : super(
          userId != null
              ? const AsyncValue.loading()
              : const AsyncValue.data(null),
        ) {
    if (userId != null) {
      _loadAvatar(userId);
    }
  }

  final AvatarService _avatarService;
  final UserService _userService;

  // The notifier can be disposed while an async call is still running.
  void _setIfMounted(AsyncValue<String?> value) {
    if (mounted) {
      state = value;
    }
  }

  Future<void> _loadAvatar(String userId) async {
    try {
      final appUser = await _userService.getAppUserById(userId);
      final avatarUrl = appUser.profile.avatarUrl;

      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        _setIfMounted(AsyncValue.data(_avatarService.getAvatarUrl(avatarUrl)));
      } else {
        _setIfMounted(const AsyncValue.data(null));
      }
    } catch (e, stack) {
      _setIfMounted(AsyncValue.error(e, stack));
    }
  }

  Future<void> uploadAvatar(File imageFile) async {
    try {
      state = const AsyncValue.loading();
      final avatarPath = await _avatarService.uploadAvatar(imageFile);
      _setIfMounted(AsyncValue.data(_avatarService.getAvatarUrl(avatarPath)));
    } catch (e, stack) {
      _setIfMounted(AsyncValue.error(e, stack));
    }
  }

  Future<void> deleteAvatar() async {
    try {
      state = const AsyncValue.loading();
      await _avatarService.deleteAvatar();
      _setIfMounted(const AsyncValue.data(null));
    } catch (e, stack) {
      _setIfMounted(AsyncValue.error(e, stack));
    }
  }
}

// autoDispose: its only consumer lives under the Home route, which is
// destroyed on logout, so the next login builds it again for the new user.
final currentUserAvatarProvider =
    StateNotifierProvider.autoDispose<AvatarNotifier, AsyncValue<String?>>(
        (ref) {
  return AvatarNotifier(
    ref.watch(avatarServiceProvider),
    ref.watch(userServiceProvider),
    userId: ref.watch(supabaseClientProvider).auth.currentUser?.id,
  );
});
