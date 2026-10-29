import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/supabase_booked_wish_removal_repository.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

final bookedWishRemovalRepositoryProvider =
    Provider.autoDispose<BookedWishRemovalRepository>((ref) {
  final repository = SupabaseBookedWishRemovalRepository(
    ref.watch(supabaseClientProvider),
  );

  ref.onDispose(repository.dispose);

  return repository;
});
