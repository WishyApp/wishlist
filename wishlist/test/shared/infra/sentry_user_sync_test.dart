import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/sentry_user_sync.dart';

AuthState _state(AuthChangeEvent event, {String? userId}) {
  final session = userId == null
      ? null
      : Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: User(
            id: userId,
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: '2024-01-01T00:00:00Z',
            email: 'someone@example.com',
          ),
        );
  return AuthState(event, session);
}

void main() {
  test('sets the user id on sign-in and clears it on sign-out', () async {
    final controller = StreamController<AuthState>();
    final calls = <String?>[];
    final sync = SentryUserSync(
      authStateChanges: controller.stream,
      setUser: (id) async => calls.add(id),
    )..start();

    controller
      ..add(_state(AuthChangeEvent.signedIn, userId: 'user-1'))
      ..add(_state(AuthChangeEvent.signedOut));
    await pumpEventQueue();

    expect(calls, ['user-1', null]);

    await sync.dispose();
    await controller.close();
  });

  test('stops listening once disposed', () async {
    final controller = StreamController<AuthState>();
    final calls = <String?>[];
    final sync = SentryUserSync(
      authStateChanges: controller.stream,
      setUser: (id) async => calls.add(id),
    )..start();

    await sync.dispose();
    expect(controller.hasListener, isFalse);

    controller.add(_state(AuthChangeEvent.signedIn, userId: 'user-1'));
    await pumpEventQueue();

    expect(calls, isEmpty);
    await controller.close();
  });

  test('applies the replayed initial session', () async {
    final controller = StreamController<AuthState>();
    final calls = <String?>[];
    final sync = SentryUserSync(
      authStateChanges: controller.stream,
      setUser: (id) async => calls.add(id),
    )..start();

    controller.add(_state(AuthChangeEvent.initialSession, userId: 'user-1'));
    await pumpEventQueue();

    expect(calls, ['user-1']);

    await sync.dispose();
    await controller.close();
  });

  test('swallows errors raised while updating the user', () async {
    final controller = StreamController<AuthState>();
    final calls = <String?>[];
    final sync = SentryUserSync(
      authStateChanges: controller.stream,
      setUser: (id) async {
        calls.add(id);
        throw StateError('boom');
      },
    )..start();

    controller
      ..add(_state(AuthChangeEvent.signedIn, userId: 'user-1'))
      ..add(_state(AuthChangeEvent.signedOut));
    await pumpEventQueue();

    expect(calls, ['user-1', null]);

    await sync.dispose();
    await controller.close();
  });

  test('ignores auth stream errors and keeps syncing', () async {
    final controller = StreamController<AuthState>();
    final calls = <String?>[];
    final uncaught = <Object>[];
    late SentryUserSync sync;

    await runZonedGuarded(
      () async {
        sync = SentryUserSync(
          authStateChanges: controller.stream,
          setUser: (id) async => calls.add(id),
        )..start();

        controller
          ..add(_state(AuthChangeEvent.signedIn, userId: 'user-1'))
          ..addError(AuthRetryableFetchException(message: 'offline'))
          ..add(_state(AuthChangeEvent.signedOut));
        await pumpEventQueue();
      },
      (error, _) => uncaught.add(error),
    );

    expect(uncaught, isEmpty);
    expect(calls, ['user-1', null]);

    await sync.dispose();
    await controller.close();
  });
}
