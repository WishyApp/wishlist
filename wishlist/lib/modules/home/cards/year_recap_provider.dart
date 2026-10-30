import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/received_wishes_summary_provider.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository_provider.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

/// The figures and the profile of the user for `year`, computed by the server
/// (`get_my_year_recap`), for the card "Ton année Wishy", its page and the
/// share image. Only read in the month of the recap (see `homeCardsProvider`)
/// and by the recap page. It is read again when the count or the latest day of
/// the received wishes changes (`receivedWishesSummaryProvider`, already live
/// on the home screen) and when a booking of the user gets received.
final yearRecapFactsProvider =
    FutureProvider.autoDispose.family<YearRecapData, int>((ref, year) async {
  // Also to start again for another user
  if (ref.watch(currentUserIdProvider) == null) {
    // Signed out: an empty recap replaces the previous user's one, nothing is
    // asked to the server.
    return YearRecapData(
      year: year,
      stats: const YearRecapStats(),
      profile: const YearRecapProfile(key: YearRecapProfileKey.minimaliste),
    );
  }
  // Only a trigger: a summary that cannot be read must not fail the recap.
  ref.watch(
    receivedWishesSummaryProvider.select(
      (summary) => (
        summary.valueOrNull?.count,
        summary.valueOrNull?.latestCompletedAt,
      ),
    ),
  );
  // The gifts the user offered count too: they are read again when one of
  // their bookings gets received. A trigger as well, it cannot fail the recap.
  ref.watch(
    bookedWishesRealtimeProvider.select(
      (bookings) => bookings.valueOrNull
          ?.map(
            (booking) => (
              booking.wish.id,
              booking.receivedAt,
              booking.bookedQuantity,
              booking.receivedQuantity,
            ),
          )
          .toIList(),
    ),
  );
  return ref.watch(yearRecapRepositoryProvider).getMyYearRecap(year);
});
