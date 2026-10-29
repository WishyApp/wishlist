import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/repositories/home_card/home_card_repository.dart';
import 'package:wishlist/shared/infra/repositories/home_card/supabase_home_card_repository.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

final homeCardRepositoryProvider =
    Provider.autoDispose<HomeCardRepository>((ref) {
  return SupabaseHomeCardRepository(ref.watch(supabaseClientProvider));
});
