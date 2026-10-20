import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

import '../../fixtures/mock_supabase.dart';

void main() {
  late FakeAuthSession session;
  late ProviderContainer container;
  late List<String?> emitted;

  void start(String? userId) {
    session = FakeAuthSession(userId: userId);
    addTearDown(session.close);
    container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(session.client)],
    );
    addTearDown(container.dispose);
    emitted = [];
    container.listen<String?>(
      currentUserIdProvider,
      (_, next) => emitted.add(next),
    );
  }

  test(
    'is available synchronously on the first read, without a session',
    () async {
      start(null);

      expect(container.read(currentUserIdProvider), isNull);
      await pumpEventQueue();
      expect(emitted, isEmpty);
    },
  );

  test(
    'is the restored user on the first read, even before any event',
    () async {
      start('user-a');

      expect(container.read(currentUserIdProvider), 'user-a');
      // The replayed initial event must not notify a duplicate.
      await pumpEventQueue();
      expect(emitted, isEmpty);
    },
  );

  test('follows sign-in, sign-out and a user switch', () async {
    start(null);

    session.signIn('user-a');
    await pumpEventQueue();
    session.signOut();
    await pumpEventQueue();
    session.signIn('user-b');
    await pumpEventQueue();

    expect(emitted, ['user-a', null, 'user-b']);
    expect(container.read(currentUserIdProvider), 'user-b');
  });

  test('does not notify for events that keep the same user', () async {
    start('user-a');

    session.refreshToken();
    session.signIn('user-a');
    await pumpEventQueue();

    expect(emitted, isEmpty);
  });

  test(
    'reads auth.currentUser, not the event, as the source of truth',
    () async {
      start('user-a');

      // currentUser is already null while only a token refresh was emitted.
      session
        ..setUserSilently(null)
        ..refreshToken();
      await pumpEventQueue();

      expect(emitted, [null]);
    },
  );

  test('a user switch without sign-out in between is notified once', () async {
    start('user-a');

    session.signIn('user-b');
    await pumpEventQueue();

    expect(emitted, ['user-b']);
  });

  test('an auth stream error is not uncaught and the id stays correct',
      () async {
    start('user-a');

    session
      ..setUserSilently('user-b')
      ..addAuthError(Exception('auth failure'));
    await pumpEventQueue();

    // An uncaught zone error would fail the test; the id is resynced.
    expect(emitted, ['user-b']);
    expect(container.read(currentUserIdProvider), 'user-b');
  });

  test(
    'a late subscriber to the replaying stream gets the current user',
    () async {
      start('user-a');
      session.signIn('user-b');
      await pumpEventQueue();

      final late = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(session.client)],
      );
      addTearDown(late.dispose);

      expect(late.read(currentUserIdProvider), 'user-b');
    },
  );
}
