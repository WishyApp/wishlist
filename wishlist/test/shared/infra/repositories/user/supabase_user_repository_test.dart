import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/infra/repositories/user/supabase_user_repository.dart';

import '../../../../fixtures/mock_supabase.dart';

void main() {
  group('getCurrentUserEmail', () {
    test('is null, without throwing, when nobody is signed in', () {
      final session = FakeAuthSession();
      addTearDown(session.close);

      final repository = SupabaseUserRepository(session.client);

      expect(repository.getCurrentUserEmail(), isNull);
    });

    test('is the email of the signed-in user', () {
      final session = FakeAuthSession(userId: 'user-a', email: 'a@x.fr');
      addTearDown(session.close);

      expect(
        SupabaseUserRepository(session.client).getCurrentUserEmail(),
        'a@x.fr',
      );
    });

    test('is null when the signed-in account has no email', () {
      final session = FakeAuthSession(userId: 'user-a');
      addTearDown(session.close);

      final repository = SupabaseUserRepository(session.client);

      expect(repository.getCurrentUserEmail(), isNull);
    });
  });
}
