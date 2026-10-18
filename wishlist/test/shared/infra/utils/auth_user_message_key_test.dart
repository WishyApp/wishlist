import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/utils/auth_user_message_key.dart';

void main() {
  group('userMessageKeyForAuthException', () {
    test('returns oldPasswordIncorrect when statusCode is 403', () {
      const e = AuthException('Forbidden', statusCode: '403');

      expect(
        userMessageKeyForAuthException(e),
        AppUserMessageKey.oldPasswordIncorrect,
      );
    });

    test('returns newPasswordShouldBeDifferent for a 422 without code', () {
      const e = AuthException('Validation failed', statusCode: '422');

      expect(
        userMessageKeyForAuthException(e),
        AppUserMessageKey.newPasswordShouldBeDifferent,
      );
    });

    test('returns newPasswordShouldBeDifferent for same_password', () {
      const e = AuthException(
        'New password should be different from the old password.',
        statusCode: '422',
        code: 'same_password',
      );

      expect(
        userMessageKeyForAuthException(e),
        AppUserMessageKey.newPasswordShouldBeDifferent,
      );
    });

    test('returns passwordTooWeak for weak_password', () {
      final e = AuthWeakPasswordException(
        message: 'Password should be at least 8 characters.',
        statusCode: '422',
        reasons: ['length'],
      );

      expect(
        userMessageKeyForAuthException(e),
        AppUserMessageKey.passwordTooWeak,
      );
    });

    test('returns reauthenticationNeeded for reauthentication_needed', () {
      const e = AuthException(
        'Password update requires reauthentication',
        statusCode: '400',
        code: 'reauthentication_needed',
      );

      expect(
        userMessageKeyForAuthException(e),
        AppUserMessageKey.reauthenticationNeeded,
      );
    });

    test('returns null for a 422 with an unrelated error code', () {
      const e = AuthException(
        'Unable to validate email address: invalid format',
        statusCode: '422',
        code: 'validation_failed',
      );

      expect(userMessageKeyForAuthException(e), isNull);
    });

    test('returns null when statusCode is 401', () {
      const e = AuthException('Unauthorized', statusCode: '401');

      expect(userMessageKeyForAuthException(e), isNull);
    });

    test('returns null when statusCode is null', () {
      const e = AuthException('Unknown error');

      expect(userMessageKeyForAuthException(e), isNull);
    });
  });
}
