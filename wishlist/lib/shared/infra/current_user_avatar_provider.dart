import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/avatar_service.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';

/// Holds only the state of the running avatar action (upload or delete).
/// The displayed avatar comes from `watchCurrentUserProfileProvider`, which
/// emits the new `avatar_url` whatever notifier started the action.
class AvatarEditNotifier extends StateNotifier<AsyncValue<void>> {
  AvatarEditNotifier(this._avatarService, this._refreshProfile)
      : super(const AsyncValue.data(null));

  final AvatarService _avatarService;
  final Future<void> Function() _refreshProfile;

  // The realtime channel can be rejoining when the action commits (the app is
  // paused by the camera or cropper on Android) and postgres_changes does not
  // replay missed events. Reload the profile and keep the loading state until
  // it is back, so the old avatar is never shown again.
  Future<void> _reloadProfile() async {
    try {
      await _refreshProfile().timeout(const Duration(seconds: 10));
    } catch (_) {
      // The action succeeded, the stream still catches up on its own.
    }
  }

  // The notifier can be disposed while an async call is still running.
  void _setIfMounted(AsyncValue<void> value) {
    if (mounted) {
      state = value;
    }
  }

  Future<void> uploadAvatar(File imageFile) async {
    try {
      state = const AsyncValue.loading();
      await _avatarService.uploadAvatar(imageFile);
      if (mounted) {
        await _reloadProfile();
      }
      _setIfMounted(const AsyncValue.data(null));
    } catch (e, stack) {
      _setIfMounted(AsyncValue.error(e, stack));
    }
  }

  Future<void> deleteAvatar() async {
    try {
      state = const AsyncValue.loading();
      await _avatarService.deleteAvatar();
      if (mounted) {
        await _reloadProfile();
      }
      _setIfMounted(const AsyncValue.data(null));
    } catch (e, stack) {
      _setIfMounted(AsyncValue.error(e, stack));
    }
  }
}

// autoDispose: disposed each time Settings is left. An action still running
// then completes in the service, and the profile stream carries its result.
// watchCurrentUserProfileProvider follows currentUserIdProvider, so the
// avatar it emits is always the one of the signed-in user.
final avatarEditProvider =
    StateNotifierProvider.autoDispose<AvatarEditNotifier, AsyncValue<void>>((
  ref,
) {
  return AvatarEditNotifier(
    ref.watch(avatarServiceProvider),
    () => ref.refresh(watchCurrentUserProfileProvider.future),
  );
});
