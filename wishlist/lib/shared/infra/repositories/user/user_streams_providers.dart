import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_stream_repository_provider.dart';
import 'package:wishlist/shared/models/profile.dart';

final watchProfileByIdProvider =
    StreamProvider.autoDispose.family<Profile?, String>((ref, userId) {
  final repository = ref.watch(userStreamRepositoryProvider);
  return repository.watchProfileById(userId);
});

final watchCurrentUserProfileProvider =
    StreamProvider.autoDispose<Profile?>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return const Stream.empty();
  }
  final repository = ref.watch(userStreamRepositoryProvider);
  return repository.watchCurrentUserProfile();
});
