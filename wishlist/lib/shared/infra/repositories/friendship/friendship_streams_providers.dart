import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_stream_repository_provider.dart';

final watchFriendsIdsProvider =
    StreamProvider.autoDispose.family<ISet<String>, String>((ref, userId) {
  final repository = ref.watch(friendshipStreamRepositoryProvider);
  return repository.watchFriendsIds(userId);
});

final watchCurrentUserFriendsIdsProvider =
    StreamProvider.autoDispose<ISet<String>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const ISetConst({}));
  }
  final repository = ref.watch(friendshipStreamRepositoryProvider);
  return repository.watchCurrentUserFriendsIds();
});

final watchCurrentUserPendingFriendsIdsProvider =
    StreamProvider.autoDispose<ISet<String>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const ISetConst({}));
  }
  final repository = ref.watch(friendshipStreamRepositoryProvider);
  return repository.watchCurrentUserPendingFriendsIds();
});

final watchCurrentUserRequestedFriendsIdsProvider =
    StreamProvider.autoDispose<ISet<String>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const ISetConst({}));
  }
  final repository = ref.watch(friendshipStreamRepositoryProvider);
  return repository.watchCurrentUserRequestedFriendsIds();
});
