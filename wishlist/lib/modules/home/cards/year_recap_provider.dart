import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/received_wishes_summary_provider.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository_provider.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

/// The figures and the profile of the user for `year`, computed by the server
/// (`get_my_year_recap`), for the card "Ton année Wishy", its page and the
/// share image. Only read in the month of the recap (see `homeCardsProvider`)
/// and by the recap page. It is read again when the count or the latest day of
/// the received wishes changes (`receivedWishesSummaryProvider`, already live
/// on the home screen).
final yearRecapFactsProvider =
    FutureProvider.autoDispose.family<YearRecapData, int>((ref, year) async {
  // Only to start again for another user
  ref.watch(currentUserIdProvider);
  // Only a trigger: a summary that cannot be read must not fail the recap.
  ref.watch(
    receivedWishesSummaryProvider.select(
      (summary) => (
        summary.valueOrNull?.count,
        summary.valueOrNull?.latestCompletedAt,
      ),
    ),
  );
  return ref.watch(yearRecapRepositoryProvider).getMyYearRecap(year);
});
