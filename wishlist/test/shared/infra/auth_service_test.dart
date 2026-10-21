import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/auth_service.dart';

import '../../fixtures/mock_supabase.dart';

void main() {
  setUpAll(() => registerFallbackValue(UserAttributes()));

  late MockGoTrueClient auth;
  late AuthService service;

  setUp(() {
    auth = MockGoTrueClient();
    final user = MockUser();
    when(() => user.email).thenReturn('me@example.com');
    when(() => auth.currentUser).thenReturn(user);
    service = AuthService(auth: auth);
  });

  void stubSignIn(Object error) {
    when(
      () => auth.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(error);
  }

  final invalidCredentials = AuthApiException(
    'Invalid login credentials',
    statusCode: '400',
    code: 'invalid_credentials',
  );

  final networkError = AuthRetryableFetchException(
    message: 'ClientException with SocketException: Failed host lookup',
  );
  final rateLimited = AuthApiException(
    'Too many requests',
    statusCode: '429',
    code: 'over_request_rate_limit',
  );

  group('AuthService.confirmPasswordIsCorrect', () {
    test('returns true when the sign-in succeeds', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      expect(await service.confirmPasswordIsCorrect('pwd'), isTrue);
    });

    test('returns false for invalid credentials', () async {
      stubSignIn(invalidCredentials);

      expect(await service.confirmPasswordIsCorrect('bad'), isFalse);
    });

    test('returns false for invalid credentials without error code', () async {
      stubSignIn(
        AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
        ),
      );

      expect(await service.confirmPasswordIsCorrect('bad'), isFalse);
    });

    test('propagates a network error', () async {
      stubSignIn(networkError);

      await expectLater(
        service.confirmPasswordIsCorrect('pwd'),
        throwsA(same(networkError)),
      );
    });

    test('propagates a rate limit error', () async {
      stubSignIn(rateLimited);

      await expectLater(
        service.confirmPasswordIsCorrect('pwd'),
        throwsA(same(rateLimited)),
      );
    });

    test('propagates a server error', () async {
      stubSignIn(
        AuthApiException(
          'Internal error',
          statusCode: '500',
          code: 'unexpected_failure',
        ),
      );

      await expectLater(
        service.confirmPasswordIsCorrect('pwd'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('AuthService.changePassword', () {
    test('reports an incorrect old password with its user message', () async {
      stubSignIn(invalidCredentials);

      await expectLater(
        service.changePassword(oldPassword: 'bad', newPassword: 'new'),
        throwsA(
          isA<AppException>().having(
            (e) => e.userMessageKey,
            'userMessageKey',
            AppUserMessageKey.oldPasswordIncorrect,
          ),
        ),
      );
    });

    for (final entry in {
      'a network error': networkError,
      'a rate limit error': rateLimited,
    }.entries) {
      test('turns ${entry.key} into a generic AppException', () async {
        stubSignIn(entry.value);

        await expectLater(
          service.changePassword(oldPassword: 'pwd', newPassword: 'new'),
          throwsA(
            isA<AppException>()
                .having((e) => e.userMessageKey, 'userMessageKey', isNull)
                .having((e) => e.cause, 'cause', same(entry.value)),
          ),
        );
        verifyNever(() => auth.updateUser(any()));
      });
    }
  });
}
