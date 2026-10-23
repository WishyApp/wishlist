import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/infra/current_user_email_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

import '../../fixtures/mock_supabase.dart';

void main() {
  late FakeAuthSession session;
  late ProviderContainer container;
  late List<String?> emitted;

  void start({String? userId, String? email}) {
    session = FakeAuthSession(userId: userId, email: email);
    addTearDown(session.close);
    container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(session.client)],
    );
    addTearDown(container.dispose);
    emitted = [];
    container.listen<String?>(
      currentUserEmailProvider,
      (_, next) => emitted.add(next),
    );
  }

  test('is null on the first read without a session', () async {
    start();

    expect(container.read(currentUserEmailProvider), isNull);
    await pumpEventQueue();
    expect(emitted, isEmpty);
  });

  test('is the restored email on the first read', () async {
    start(userId: 'user-a', email: 'a@x.fr');

    expect(container.read(currentUserEmailProvider), 'a@x.fr');
    await pumpEventQueue();
    expect(emitted, isEmpty);
  });

  test('follows sign-in, sign-out and a user switch', () async {
    start();

    session.signIn('user-a', email: 'a@x.fr');
    await pumpEventQueue();
    session.signOut();
    await pumpEventQueue();
    session.signIn('user-b', email: 'b@x.fr');
    await pumpEventQueue();

    expect(emitted, ['a@x.fr', null, 'b@x.fr']);
    expect(container.read(currentUserEmailProvider), 'b@x.fr');
  });

  test('does not notify for events that keep the same email', () async {
    start(userId: 'user-a', email: 'a@x.fr');

    session.refreshToken();
    session.signIn('user-a', email: 'a@x.fr');
    await pumpEventQueue();

    expect(emitted, isEmpty);
  });

  test('resyncs and survives an error pushed in the auth stream', () async {
    start(userId: 'user-a', email: 'a@x.fr');
    container.read(currentUserEmailProvider);

    session.setUserSilently(null);
    session.addAuthError(Exception('boom'));
    await pumpEventQueue();

    expect(emitted, [null]);
  });
}
