import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/avatar_service.dart';

/// Holds only the state of the running avatar action (upload or delete).
/// The displayed avatar comes from `watchCurrentUserProfileProvider`, which
/// emits the new `avatar_url` whatever notifier started the action.
class AvatarEditNotifier extends StateNotifier<AsyncValue<void>> {
  AvatarEditNotifier(this._avatarService) : super(const AsyncValue.data(null));

  final AvatarService _avatarService;

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
      _setIfMounted(const AsyncValue.data(null));
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

// autoDispose: disposed each time Settings is left. An action still running
// then completes in the service, and the profile stream carries its result.
final avatarEditProvider =
    StateNotifierProvider.autoDispose<AvatarEditNotifier, AsyncValue<void>>((
  ref,
) {
  return AvatarEditNotifier(ref.watch(avatarServiceProvider));
});
