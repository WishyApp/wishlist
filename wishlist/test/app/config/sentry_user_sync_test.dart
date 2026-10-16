import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/config/sentry_user_sync.dart';

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
}
