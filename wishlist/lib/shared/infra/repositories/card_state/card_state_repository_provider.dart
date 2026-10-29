import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/repositories/card_state/card_state_repository.dart';
import 'package:wishlist/shared/infra/repositories/card_state/supabase_card_state_repository.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

final cardStateRepositoryProvider =
    Provider.autoDispose<CardStateRepository>((ref) {
  return SupabaseCardStateRepository(ref.watch(supabaseClientProvider));
});
