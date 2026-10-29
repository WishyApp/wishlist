import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_stream_repository_provider.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';

/// Count and latest day of the wishes the current user received, for the home
/// screen. It does not keep `completedWishesRealtimeProvider` alive: that one
/// listens to every wish, wishlist and profile.
final receivedWishesSummaryProvider =
    StreamProvider.autoDispose<ReceivedWishesSummary>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    // Signed out: an empty value replaces the previous user's one.
    return Stream.value(const ReceivedWishesSummary.empty());
  }

  return ref
      .watch(userCompletedWishStreamRepositoryProvider)
      .watchReceivedWishesSummary(userId);
});
