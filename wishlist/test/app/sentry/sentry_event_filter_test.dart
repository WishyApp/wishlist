import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/sentry/sentry_event_filter.dart';

void main() {
  SentryEvent eventFor(Object error) => SentryEvent(throwable: error);

  group('dropExpectedErrors', () {
    for (final code in [
      'refresh_token_already_used',
      'refresh_token_not_found',
    ]) {
      test('drops the refresh token error $code', () {
        final error = AuthApiException(
          'Invalid Refresh Token',
          statusCode: '400',
          code: code,
        );

        expect(dropExpectedErrors(eventFor(error), Hint()), isNull);
      });
    }

    test('keeps another auth error', () {
      const error = AuthApiException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      );
      final event = eventFor(error);

      expect(dropExpectedErrors(event, Hint()), same(event));
    });

    test('keeps any other error and a message without error', () {
      final withError = eventFor(StateError('bug'));
      final withoutError = SentryEvent(message: SentryMessage('hello'));

      expect(dropExpectedErrors(withError, Hint()), same(withError));
      expect(dropExpectedErrors(withoutError, Hint()), same(withoutError));
    });
  });
}
