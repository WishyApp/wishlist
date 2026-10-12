import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/avatar_service.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';

class AvatarNotifier extends StateNotifier<AsyncValue<String?>> {
  AvatarNotifier(
    this._avatarService,
    this._userService, {
    required bool hasSession,
  }) : super(
          hasSession ? const AsyncValue.loading() : const AsyncValue.data(null),
        ) {
    if (hasSession) {
      _loadCurrentUserAvatar();
    }
  }

  final AvatarService _avatarService;
  final UserService _userService;

  Future<void> _loadCurrentUserAvatar() async {
    try {
      final currentUserId = _userService.getCurrentUserId();
      final appUser = await _userService.getAppUserById(currentUserId);
      // The session may have changed while loading.
      if (!mounted) {
        return;
      }
      final avatarUrl = appUser.profile.avatarUrl;

      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        final fullAvatarUrl = _avatarService.getAvatarUrl(avatarUrl);
        state = AsyncValue.data(fullAvatarUrl);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> uploadAvatar(File imageFile) async {
    try {
      state = const AsyncValue.loading();
      final avatarPath = await _avatarService.uploadAvatar(imageFile);
      if (!mounted) {
        return;
      }
      final fullAvatarUrl = _avatarService.getAvatarUrl(avatarPath);

      state = AsyncValue.data(fullAvatarUrl);
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> deleteAvatar() async {
    try {
      state = const AsyncValue.loading();
      await _avatarService.deleteAvatar();
      if (!mounted) {
        return;
      }
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
}

final currentUserAvatarProvider =
    StateNotifierProvider<AvatarNotifier, AsyncValue<String?>>((ref) {
  final avatarService = ref.watch(avatarServiceProvider);
  final userService = ref.watch(userServiceProvider);
  final auth = ref.watch(supabaseClientProvider).auth;
  final userId = auth.currentUser?.id;
  // onAuthStateChange replays its last event to each new subscriber, so only
  // rebuild when the user actually differs from the one this state was built
  // for.
  final authSubscription = auth.onAuthStateChange.listen(
    (data) {
      if (data.session?.user.id != userId) {
        ref.invalidateSelf();
      }
    },
    // The stream replays errors (e.g. a failed token refresh while offline).
    onError: (Object _) {},
  );
  ref.onDispose(authSubscription.cancel);
  return AvatarNotifier(
    avatarService,
    userService,
    hasSession: userId != null,
  );
});
