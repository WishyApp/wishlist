import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_repository.dart';
import 'package:wishlist/shared/infra/repositories/friendship/supabase_friendship_repository.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

final friendshipRepositoryProvider = Provider<FriendshipRepository>((ref) {
  // The repository reads the current user from auth at call time, so it is
  // stateless; depending on the user id still rebuilds everything that holds
  // it (friendship service, stream repository and its open channels) when the
  // user changes, instead of keeping the previous session's state.
  ref.watch(currentUserIdProvider);
  return SupabaseFriendshipRepository(ref.watch(supabaseClientProvider));
});
