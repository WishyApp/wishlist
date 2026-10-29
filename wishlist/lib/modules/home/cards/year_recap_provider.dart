import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/modules/home/cards/card_builders.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';

/// The wishes the user received, read once. Not the live stream
/// (completedWishesRealtimeProvider): it listens to four tables without a
/// filter and the home screen must not keep it all year for a card shown in
/// December. Only read in the month of the recap (see `homeCardsProvider`)
/// and by the recap page.
final receivedWishesSnapshotProvider =
    FutureProvider.autoDispose<IList<CompletedWishWithDetails>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const IListConst([]);
  }
  return ref
      .watch(userCompletedWishRepositoryProvider)
      .getCompletedWishesByUser(userId);
});

/// What the user received and gave during `year`, for the card "Ton année
/// Wishy" and its page. The bookings come from the live provider the home
/// already listens to; only a change of what the recap reads reloads it.
final yearRecapFactsProvider =
    FutureProvider.autoDispose.family<YearRecapFacts, int>((ref, year) async {
  final received = await ref.watch(receivedWishesSnapshotProvider.future);
  await ref.watch(
    bookedWishesRealtimeProvider.selectAsync(
      (list) => [
        for (final b in list)
          if (b.receivedAt != null)
            (wishId: b.wish.id, ownerId: b.ownerId, receivedAt: b.receivedAt),
      ].toIList(),
    ),
  );
  final bookings = ref.read(bookedWishesRealtimeProvider).valueOrNull;
  return yearRecapFacts(
    received: received.toList(),
    bookings: bookings?.toList() ?? const [],
    year: year,
  );
});
