import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/infra/repositories/friendship/supabase_friendship_repository.dart';

import '../../../../fixtures/mock_supabase.dart';

void main() {
  test('currentUserId follows the session after an account switch', () {
    final client = MockSupabaseClient();
    final auth = MockGoTrueClient();
    final firstUser = MockUser();
    final secondUser = MockUser();
    when(() => client.auth).thenReturn(auth);
    when(() => firstUser.id).thenReturn('user-1');
    when(() => secondUser.id).thenReturn('user-2');
    when(() => auth.currentUser).thenReturn(firstUser);

    final repository = SupabaseFriendshipRepository(client);
    expect(repository.currentUserId, 'user-1');

    when(() => auth.currentUser).thenReturn(secondUser);
    expect(repository.currentUserId, 'user-2');
  });
}
