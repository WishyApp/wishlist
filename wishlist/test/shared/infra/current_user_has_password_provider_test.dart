import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/infra/current_user_has_password_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

import '../../fixtures/mock_supabase.dart';

void main() {
  late FakeAuthSession session;
  late ProviderContainer container;

  void start({String? userId}) {
    session = FakeAuthSession(userId: userId);
    addTearDown(session.close);
    container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(session.client)],
    );
    addTearDown(container.dispose);
    container.listen<bool>(currentUserHasPasswordProvider, (_, __) {});
  }

  test('is true for an email account', () {
    start(userId: 'user-a');

    expect(container.read(currentUserHasPasswordProvider), isTrue);
  });

  test('is true without a session', () {
    start();

    expect(container.read(currentUserHasPasswordProvider), isTrue);
  });

  test('follows the account on sign-in and sign-out', () async {
    start();

    session.signIn('user-g', providers: ['google']);
    await pumpEventQueue();
    expect(container.read(currentUserHasPasswordProvider), isFalse);

    session.signOut();
    await pumpEventQueue();
    expect(container.read(currentUserHasPasswordProvider), isTrue);
  });
}
