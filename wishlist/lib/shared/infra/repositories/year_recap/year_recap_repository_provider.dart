import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/supabase_year_recap_repository.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

final yearRecapRepositoryProvider =
    Provider.autoDispose<YearRecapRepository>((ref) {
  return SupabaseYearRecapRepository(ref.watch(supabaseClientProvider));
});
