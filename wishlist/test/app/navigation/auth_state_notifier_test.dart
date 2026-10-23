import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/navigation/app_redirect.dart';

void main() {
  test('notifies on every auth event', () async {
    final events = StreamController<AuthState>();
    final notifier = AuthStateNotifier(events.stream);
    addTearDown(() async {
      notifier.dispose();
      await events.close();
    });
    var notifications = 0;
    notifier.addListener(() => notifications++);

    events
      ..add(const AuthState(AuthChangeEvent.signedIn, null))
      ..add(const AuthState(AuthChangeEvent.signedOut, null));
    await pumpEventQueue();

    expect(notifications, 2);
  });

  // gotrue pushes refresh failures into onAuthStateChange: they must not
  // reach the zone (and Sentry).
  test('swallows auth stream errors and keeps notifying', () async {
    final uncaught = <Object>[];
    await runZonedGuarded(
      () async {
        final events = StreamController<AuthState>();
        final notifier = AuthStateNotifier(events.stream);
        var notifications = 0;
        notifier.addListener(() => notifications++);

        events
          ..addError(AuthRetryableFetchException(message: 'offline'))
          ..add(const AuthState(AuthChangeEvent.signedOut, null));
        await pumpEventQueue();

        expect(notifications, 1);
        notifier.dispose();
        await events.close();
      },
      (error, _) => uncaught.add(error),
    );

    expect(uncaught, isEmpty);
  });
}
